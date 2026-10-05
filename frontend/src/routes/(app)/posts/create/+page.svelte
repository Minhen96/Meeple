<script lang="ts">
	import { onDestroy, tick } from 'svelte';
	import { beforeNavigate, goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { postsApi } from '$lib/api/posts';
	import { uploadApi } from '$lib/api/upload';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import { compressPostImage, formatBytes } from '$lib/utils/image';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ProgressBar from '$lib/components/ui/ProgressBar.svelte';
	import Spinner from '$lib/components/ui/Spinner.svelte';
	import PostTagsEditor from '$lib/components/social/PostTagsEditor.svelte';
	import { moveItem, type TaggedFriend, type TaggedGame } from '$lib/components/social/postTags';
	import { toast } from 'svelte-sonner';

	const MAX_IMAGES = 10;
	const MAX_CAPTION = 2000;

	type UploadStatus = 'compressing' | 'waiting' | 'uploading' | 'done' | 'error';
	interface Upload {
		id: string;
		original: File;
		preview: string;
		status: UploadStatus;
		/** 0–100, compression then upload. */
		progress: number;
		compressed: File | null;
		key: string | null;
	}

	const eventId = $page.url.searchParams.get('eventId');

	let uploads = $state<Upload[]>([]);
	let caption = $state('');
	let location = $state('');
	let playedAtLocal = $state(toLocalInput(new Date()));
	let taggedGame = $state<TaggedGame | null>(null);
	let taggedFriends = $state<TaggedFriend[]>([]);
	let submitting = $state(false);
	let error = $state('');
	let fileInput = $state<HTMLInputElement>();

	// Photo reordering: drag by the handle (pointer events) or the move buttons / arrow keys.
	// The list itself is re-ordered as the pointer passes over another photo, no transforms.
	let dragId = $state<string | null>(null);
	let photoStrip = $state<HTMLDivElement>();
	let reorderStatus = $state('');

	// Discard guard
	let pendingNavigation = $state<URL | null>(null);
	let leaving = false;

	const dirty = $derived(
		uploads.length > 0 ||
			caption.trim() !== '' ||
			location.trim() !== '' ||
			taggedGame !== null ||
			taggedFriends.length > 0
	);
	const busyUploads = $derived(
		uploads.filter(
			(u) => u.status === 'compressing' || u.status === 'waiting' || u.status === 'uploading'
		)
	);
	const failedUploads = $derived(uploads.filter((u) => u.status === 'error'));
	const doneCount = $derived(uploads.filter((u) => u.status === 'done').length);
	const hasContent = $derived(uploads.length > 0 || caption.trim() !== '' || taggedGame !== null);
	const maxPlayedAt = $derived(toLocalInput(new Date()));

	function toLocalInput(d: Date): string {
		const pad = (n: number) => String(n).padStart(2, '0');
		return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
	}

	// ─── Images ──────────────────────────────────────────────────────────────

	function patch(id: string, changes: Partial<Upload>) {
		uploads = uploads.map((u) => (u.id === id ? { ...u, ...changes } : u));
	}

	function handleFileSelect(event: Event) {
		const target = event.currentTarget as HTMLInputElement;
		const files = Array.from(target.files ?? []);
		target.value = '';
		if (files.length === 0) return;
		const room = MAX_IMAGES - uploads.length;
		if (files.length > room) toast.error(m('social.create.maxImages'));
		const added: Upload[] = files.slice(0, Math.max(room, 0)).map((file) => ({
			id: crypto.randomUUID(),
			original: file,
			preview: URL.createObjectURL(file),
			status: 'compressing',
			progress: 0,
			compressed: null,
			key: null
		}));
		uploads = [...uploads, ...added];
		added.forEach((u) => void processUpload(u.id));
	}

	/** Compress (if not done yet) then presign + upload one image. */
	async function processUpload(id: string) {
		const current = uploads.find((u) => u.id === id);
		if (!current) return;
		let compressed = current.compressed;
		if (!compressed) {
			patch(id, { status: 'compressing', progress: 0 });
			try {
				const result = await compressPostImage(current.original, (fraction) =>
					patch(id, { progress: Math.round(fraction * 50) })
				);
				compressed = result.file;
			} catch {
				if (uploads.some((u) => u.id === id)) {
					patch(id, { status: 'error' });
					toast.error(m('social.create.notAnImage', { name: current.original.name }));
				}
				return;
			}
			if (!uploads.some((u) => u.id === id)) return; // removed meanwhile
			patch(id, { compressed, status: 'waiting', progress: 50 });
		}
		patch(id, { status: 'uploading', progress: 60 });
		try {
			const { key } = await uploadApi.presignAndUpload(compressed);
			if (uploads.some((u) => u.id === id)) patch(id, { status: 'done', progress: 100, key });
		} catch {
			if (uploads.some((u) => u.id === id)) patch(id, { status: 'error', progress: 50 });
		}
	}

	function removeImage(id: string) {
		const target = uploads.find((u) => u.id === id);
		if (target) URL.revokeObjectURL(target.preview);
		uploads = uploads.filter((u) => u.id !== id);
	}

	onDestroy(() => uploads.forEach((u) => URL.revokeObjectURL(u.preview)));

	// ─── Reordering ──────────────────────────────────────────────────────────

	const indexOf = (id: string) => uploads.findIndex((u) => u.id === id);

	function announceOrder(id: string) {
		reorderStatus = m('common.photoOrder.moved', {
			position: indexOf(id) + 1,
			total: uploads.length
		});
	}

	/**
	 * Move a photo by one slot. Keyed re-rendering moves the DOM node, which can drop focus,
	 * so focus returns to the control the user pressed (or the handle once at either end).
	 */
	async function movePhoto(id: string, delta: number, control: 'handle' | 'left' | 'right') {
		const from = indexOf(id);
		const to = from + delta;
		if (from < 0 || to < 0 || to >= uploads.length) return;
		uploads = moveItem(uploads, from, to);
		announceOrder(id);
		await tick();
		const tile = photoStrip?.querySelector<HTMLElement>(`[data-photo-id="${id}"]`);
		const target = tile?.querySelector<HTMLButtonElement>(`[data-reorder="${control}"]`);
		(target && !target.disabled
			? target
			: tile?.querySelector<HTMLButtonElement>('[data-reorder="handle"]')
		)?.focus();
	}

	function onHandleKeydown(event: KeyboardEvent, id: string) {
		const delta = event.key === 'ArrowLeft' ? -1 : event.key === 'ArrowRight' ? 1 : 0;
		if (delta === 0) return;
		event.preventDefault();
		void movePhoto(id, delta, 'handle');
	}

	function startDrag(event: PointerEvent, id: string) {
		if (event.button !== 0 || uploads.length < 2) return;
		event.preventDefault();
		(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
		dragId = id;
	}

	function dragMove(event: PointerEvent) {
		if (dragId === null) return;
		const over = document
			.elementFromPoint(event.clientX, event.clientY)
			?.closest<HTMLElement>('[data-photo-id]')?.dataset.photoId;
		if (over && over !== dragId) uploads = moveItem(uploads, indexOf(dragId), indexOf(over));
		// Scroll the strip while dragging near its edges
		if (photoStrip) {
			const rect = photoStrip.getBoundingClientRect();
			if (event.clientX < rect.left + 40) photoStrip.scrollLeft -= 12;
			else if (event.clientX > rect.right - 40) photoStrip.scrollLeft += 12;
		}
	}

	function endDrag() {
		if (dragId === null) return;
		announceOrder(dragId);
		dragId = null;
	}

	// ─── Submit & guard ──────────────────────────────────────────────────────

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		error = '';
		if (!hasContent) {
			error = m('social.create.empty');
			return;
		}
		if (busyUploads.length > 0) return;
		if (failedUploads.length > 0) {
			error = m('social.create.fixUploads');
			return;
		}
		submitting = true;
		try {
			const playedAt = playedAtLocal ? new Date(playedAtLocal) : null;
			const created = await postsApi.createPost({
				caption: caption.trim() || undefined,
				location: location.trim() || undefined,
				playedAt:
					playedAt && !Number.isNaN(playedAt.getTime()) ? playedAt.toISOString() : undefined,
				imageKeys: uploads.map((u) => u.key).filter((k): k is string => k !== null),
				gameId: taggedGame?.id ?? undefined,
				eventId: eventId ?? undefined,
				taggedUserIds: taggedFriends.map((f) => f.id)
			});
			toast.success(m('social.create.posted'));
			leaving = true;
			await goto(eventId ? `/posts/${created.id}` : '/');
		} catch (err) {
			error =
				err instanceof ApiRequestError ? errorMessage(err.code) : m('social.create.failedGeneric');
		} finally {
			submitting = false;
		}
	}

	beforeNavigate(({ cancel, to, type }) => {
		if (leaving || !dirty || submitting) return;
		if (type === 'leave') {
			cancel(); // browser shows its own "leave site?" prompt
			return;
		}
		cancel();
		pendingNavigation = to?.url ?? new URL('/', window.location.origin);
	});

	function discard() {
		const target = pendingNavigation;
		pendingNavigation = null;
		leaving = true;
		void goto(target ?? '/');
	}
</script>

<svelte:head><title>{m('social.create.title')} — Meeple</title></svelte:head>

<div class="relative min-h-screen overflow-x-hidden pb-24">
	<div class="absolute -left-32 -top-32 -z-10 h-80 w-80 rounded-full bg-tertiary/10 blur-3xl"></div>
	<div
		class="absolute -right-32 bottom-1/4 -z-10 h-96 w-96 rounded-full bg-primary/5 blur-3xl"
	></div>

	<!-- Header -->
	<div class="sticky top-4 z-20 mb-6 mt-4 flex items-center gap-3 px-4">
		<button
			type="button"
			onclick={() => history.back()}
			class="flex h-11 w-11 items-center justify-center rounded-2xl border border-white/10 bg-surface-container-low/80 text-on-surface shadow-sm backdrop-blur-md transition-all hover:bg-surface-container-high active:scale-90"
			aria-label={m('social.detail.back')}
		>
			<span class="material-symbols-outlined text-[24px]">arrow_back</span>
		</button>
		<div class="flex-1 pr-11 text-center">
			<h2 class="font-headline text-2xl font-black tracking-tight text-on-surface">
				{m('social.create.title')}
			</h2>
			{#if eventId}
				<p class="font-label text-[10px] uppercase tracking-widest text-tertiary">
					{m('social.create.forEvent')}
				</p>
			{/if}
		</div>
	</div>

	<form onsubmit={handleSubmit} class="mx-auto max-w-2xl space-y-6 px-4" novalidate>
		{#if error}
			<div
				class="rounded-2xl bg-error-container px-4 py-3 text-xs font-semibold text-on-error-container"
				role="alert"
			>
				{error}
			</div>
		{/if}

		<!-- Photos (optional) -->
		<div class="space-y-3">
			<div class="flex items-center justify-between px-1">
				<h3
					class="font-label text-[10px] font-black uppercase tracking-widest text-on-surface-variant/70"
				>
					{m('social.create.photos', { count: uploads.length })}
				</h3>
				{#if uploads.length > 0 && uploads.length < MAX_IMAGES}
					<button
						type="button"
						onclick={() => fileInput?.click()}
						class="text-[10px] font-bold uppercase text-primary"
					>
						{m('social.create.addMore')}
					</button>
				{/if}
			</div>

			{#if uploads.length === 0}
				<button
					type="button"
					onclick={() => fileInput?.click()}
					class="flex w-full flex-col items-center justify-center gap-3 rounded-[2rem] bg-surface-container-low py-10 text-on-surface-variant transition-all hover:bg-surface-container active:scale-[0.99]"
				>
					<div
						class="flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-container-high shadow-inner"
					>
						<span class="material-symbols-outlined text-3xl text-tertiary">add_photo_alternate</span
						>
					</div>
					<div class="text-center">
						<p class="font-headline text-sm font-black">{m('social.create.addPhotos')}</p>
						<p class="text-[10px] uppercase tracking-tighter opacity-60">
							{m('social.create.pickerHint')}
						</p>
					</div>
				</button>
			{:else}
				<div bind:this={photoStrip} class="hide-scrollbar flex gap-3 overflow-x-auto pb-2">
					{#each uploads as upload, index (upload.id)}
						<div
							class="relative w-32 flex-shrink-0 rounded-2xl transition-opacity {dragId ===
							upload.id
								? 'opacity-60 ring-2 ring-primary'
								: ''}"
							data-photo-id={upload.id}
						>
							<button
								type="button"
								disabled={upload.status !== 'error'}
								onclick={() => processUpload(upload.id)}
								aria-label={upload.status === 'error' ? m('social.create.retryImage') : undefined}
								class="relative block aspect-square w-full overflow-hidden rounded-2xl shadow-sm"
							>
								<img
									src={upload.preview}
									alt=""
									class="h-full w-full object-cover"
									class:opacity-60={upload.status !== 'done'}
								/>
								{#if upload.status === 'error'}
									<span
										class="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-error/70 p-2 text-center text-[10px] font-bold text-on-error"
									>
										<span class="material-symbols-outlined">refresh</span>{m(
											'social.create.failed'
										)}
									</span>
								{/if}
							</button>
							<button
								type="button"
								onclick={() => removeImage(upload.id)}
								class="absolute right-1.5 top-1.5 flex h-6 w-6 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur-sm"
								aria-label={m('social.create.removeImage')}
							>
								<span class="material-symbols-outlined text-xs">close</span>
							</button>
							{#if uploads.length > 1}
								<button
									type="button"
									onpointerdown={(e) => startDrag(e, upload.id)}
									onpointermove={dragMove}
									onpointerup={endDrag}
									onpointercancel={endDrag}
									onkeydown={(e) => onHandleKeydown(e, upload.id)}
									data-reorder="handle"
									class="absolute left-1.5 top-1.5 flex h-6 w-6 touch-none cursor-grab items-center justify-center rounded-full bg-black/60 text-white backdrop-blur-sm active:cursor-grabbing"
									aria-label={m('common.photoOrder.handle', { position: index + 1 })}
								>
									<span class="material-symbols-outlined text-xs">drag_indicator</span>
								</button>
								<div class="mt-1.5 flex justify-between">
									<button
										type="button"
										onclick={() => movePhoto(upload.id, -1, 'left')}
										data-reorder="left"
										disabled={index === 0}
										class="flex h-7 w-7 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-opacity disabled:opacity-30"
										aria-label={m('common.photoOrder.moveLeft', { position: index + 1 })}
									>
										<span class="material-symbols-outlined text-sm">chevron_left</span>
									</button>
									<button
										type="button"
										onclick={() => movePhoto(upload.id, 1, 'right')}
										data-reorder="right"
										disabled={index === uploads.length - 1}
										class="flex h-7 w-7 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-opacity disabled:opacity-30"
										aria-label={m('common.photoOrder.moveRight', { position: index + 1 })}
									>
										<span class="material-symbols-outlined text-sm">chevron_right</span>
									</button>
								</div>
							{/if}
							<div class="mt-1.5 space-y-1">
								{#if upload.status !== 'done' && upload.status !== 'error'}
									<ProgressBar value={upload.progress} tone="tertiary" class="h-1.5 w-full" />
								{/if}
								<p class="truncate font-label text-[10px] text-on-surface-variant">
									{#if upload.status === 'compressing'}{m('social.create.compressing')}
									{:else if upload.status === 'waiting'}{m('social.create.waiting')}
									{:else if upload.status === 'uploading'}{m('social.create.uploading')}
									{:else if upload.compressed}{formatBytes(upload.compressed.size)}{/if}
								</p>
							</div>
						</div>
					{/each}
					{#if uploads.length < MAX_IMAGES}
						<button
							type="button"
							onclick={() => fileInput?.click()}
							aria-label={m('social.create.addMore')}
							class="flex aspect-square w-32 flex-shrink-0 flex-col items-center justify-center rounded-2xl bg-surface-container-low text-on-surface-variant"
						>
							<span class="material-symbols-outlined text-xl">add</span>
						</button>
					{/if}
				</div>
				<p class="sr-only" aria-live="polite">{reorderStatus}</p>
				{#if uploads.length > 1}
					<p class="px-1 font-label text-[10px] text-on-surface-variant/70">
						{m('common.photoOrder.hint')}
					</p>
				{/if}
				{#if busyUploads.length > 0}
					<p
						class="flex items-center gap-2 px-1 font-label text-xs text-on-surface-variant"
						aria-live="polite"
					>
						<Spinner className="h-3.5 w-3.5" />
						{m('social.create.uploadingCount', { done: doneCount, total: uploads.length })}
					</p>
				{/if}
			{/if}
			<input
				type="file"
				multiple
				accept="image/*"
				bind:this={fileInput}
				onchange={handleFileSelect}
				class="hidden"
			/>
		</div>

		<!-- Caption -->
		<div class="space-y-2 rounded-[2rem] bg-surface-container-low p-6 shadow-sm">
			<textarea
				rows="4"
				maxlength={MAX_CAPTION}
				placeholder={m('social.create.captionPlaceholder')}
				aria-label={m('social.edit.caption')}
				bind:value={caption}
				class="w-full resize-none rounded-2xl bg-surface-container-highest px-4 py-3 font-body text-base text-on-surface placeholder:text-on-surface-variant/40 focus:outline-none focus:ring-2 focus:ring-primary/30"
			></textarea>
			<p class="text-right font-label text-[10px] text-on-surface-variant">
				{m('social.create.captionCount', { count: caption.length })}
			</p>
		</div>

		<!-- Game + friends -->
		<div class="grid grid-cols-1 gap-3">
			<PostTagsEditor bind:game={taggedGame} bind:friends={taggedFriends} />

			<label class="flex items-center gap-4 rounded-2xl bg-surface-container-low p-4">
				<span
					class="flex h-10 w-10 items-center justify-center rounded-xl bg-tertiary/10 text-tertiary"
				>
					<span class="material-symbols-outlined text-[20px]">location_on</span>
				</span>
				<span class="flex-1">
					<span class="block text-[10px] uppercase tracking-tighter text-on-surface-variant/60"
						>{m('social.create.location')}</span
					>
					<input
						type="text"
						maxlength="100"
						bind:value={location}
						placeholder={m('social.create.locationPlaceholder')}
						class="w-full bg-transparent text-sm font-bold text-on-surface outline-none placeholder:font-normal placeholder:text-on-surface-variant/40"
					/>
				</span>
			</label>

			<label class="flex items-center gap-4 rounded-2xl bg-surface-container-low p-4">
				<span
					class="flex h-10 w-10 items-center justify-center rounded-xl bg-surface-container-high text-on-surface-variant"
				>
					<span class="material-symbols-outlined text-[20px]">schedule</span>
				</span>
				<span class="flex-1">
					<span class="block text-[10px] uppercase tracking-tighter text-on-surface-variant/60"
						>{m('social.create.playedAt')}</span
					>
					<input
						type="datetime-local"
						max={maxPlayedAt}
						bind:value={playedAtLocal}
						class="w-full bg-transparent text-sm font-bold text-on-surface outline-none"
					/>
				</span>
			</label>
		</div>

		<div class="pt-4">
			<button
				type="submit"
				disabled={submitting || busyUploads.length > 0}
				class="flex h-16 w-full items-center justify-center gap-3 overflow-hidden rounded-3xl bg-gradient-to-r from-primary to-primary-container font-headline text-lg font-black text-on-primary shadow-[0_8px_24px_rgba(137,81,0,0.20)] transition-all hover:scale-[1.01] active:scale-[0.98] disabled:opacity-50"
			>
				{#if submitting}
					<Spinner className="h-5 w-5" />
					<span>{m('social.create.posting')}</span>
				{:else}
					<span class="material-symbols-outlined text-[20px]">send</span>
					<span>{m('social.create.share')}</span>
				{/if}
			</button>
		</div>
	</form>
</div>

{#if pendingNavigation}
	<ConfirmDialog
		title={m('social.create.discardTitle')}
		message={m('social.create.discardBody')}
		confirmLabel={m('social.create.discard')}
		cancelLabel={m('social.create.keepEditing')}
		danger
		onConfirm={discard}
		onCancel={() => (pendingNavigation = null)}
	/>
{/if}
