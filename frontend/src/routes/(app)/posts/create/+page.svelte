<script lang="ts">
	import { onDestroy } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { beforeNavigate, goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { postsApi } from '$lib/api/posts';
	import { uploadApi } from '$lib/api/upload';
	import { gamesApi } from '$lib/api/games';
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import { compressPostImage, formatBytes } from '$lib/utils/image';
	import Button from '$lib/components/ui/Button.svelte';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ProgressBar from '$lib/components/ui/ProgressBar.svelte';
	import Spinner from '$lib/components/ui/Spinner.svelte';
	import type { GameSearchResult, User } from '$lib/types';
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
	let taggedGame = $state<GameSearchResult | null>(null);
	let taggedFriends = $state<User[]>([]);
	let submitting = $state(false);
	let error = $state('');
	let fileInput = $state<HTMLInputElement>();

	// Modals
	let showGameSearch = $state(false);
	let showFriendSearch = $state(false);
	let gameQuery = $state('');
	let gameResults = $state<GameSearchResult[]>([]);
	let gameSearchTimer: ReturnType<typeof setTimeout> | undefined;
	let friendsList = $state<User[] | null>(null);

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

	// ─── Tagging ─────────────────────────────────────────────────────────────

	function onGameQuery() {
		clearTimeout(gameSearchTimer);
		const q = gameQuery.trim();
		if (q.length < 2) {
			gameResults = [];
			return;
		}
		gameSearchTimer = setTimeout(async () => {
			try {
				// Only games already in our catalogue (with an id) can be tagged
				gameResults = (await gamesApi.search(q)).filter((g) => g.id !== null);
			} catch {
				gameResults = [];
			}
		}, 300);
	}

	async function openFriends() {
		showFriendSearch = true;
		if (friendsList !== null) return;
		try {
			friendsList = (await friendsApi.getFriends(0, 100)).data;
		} catch {
			friendsList = [];
		}
	}

	function toggleFriend(friend: User) {
		taggedFriends = taggedFriends.some((f) => f.id === friend.id)
			? taggedFriends.filter((f) => f.id !== friend.id)
			: [...taggedFriends, friend];
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
				<div class="hide-scrollbar flex gap-3 overflow-x-auto pb-2">
					{#each uploads as upload (upload.id)}
						<div class="relative w-32 flex-shrink-0">
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
			<div class="flex items-center gap-4 rounded-2xl bg-surface-container-low p-4">
				<button
					type="button"
					onclick={() => (showGameSearch = true)}
					class="flex flex-1 items-center gap-4 text-left"
				>
					<span
						class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary"
					>
						<span class="material-symbols-outlined text-[20px]">casino</span>
					</span>
					<span class="flex-1">
						<span class="block text-sm font-bold"
							>{taggedGame ? taggedGame.title : m('social.create.tagGame')}</span
						>
						<span class="block text-[10px] uppercase tracking-tighter text-on-surface-variant/60"
							>{m('social.create.whichGame')}</span
						>
					</span>
				</button>
				{#if taggedGame}
					<button
						type="button"
						onclick={() => (taggedGame = null)}
						class="text-on-surface-variant/60 transition-colors hover:text-on-surface"
						aria-label={m('social.create.removeGame')}
					>
						<span class="material-symbols-outlined text-sm">close</span>
					</button>
				{/if}
			</div>

			<button
				type="button"
				onclick={openFriends}
				class="flex items-center gap-4 rounded-2xl bg-surface-container-low p-4 text-left transition-all hover:bg-secondary/10 active:scale-[0.98]"
			>
				<span
					class="flex h-10 w-10 items-center justify-center rounded-xl bg-secondary/10 text-secondary"
				>
					<span class="material-symbols-outlined text-[20px]">group</span>
				</span>
				<span class="flex-1">
					<span class="block text-sm font-bold">
						{taggedFriends.length === 0
							? m('social.create.tagFriends')
							: m('social.create.friendsTagged', { count: taggedFriends.length })}
					</span>
					<span class="block text-[10px] uppercase tracking-tighter text-on-surface-variant/60"
						>{m('social.create.whoPlayed')}</span
					>
				</span>
				{#if taggedFriends.length > 0}
					<span class="flex -space-x-2">
						{#each taggedFriends.slice(0, 3) as friend (friend.id)}
							<Avatar
								src={friend.avatarUrl}
								name={friend.displayName ?? friend.username}
								size="xs"
								className="ring-2 ring-surface"
							/>
						{/each}
					</span>
				{/if}
			</button>

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

<!-- Game search -->
{#if showGameSearch}
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4" transition:fade>
		<button
			type="button"
			class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (showGameSearch = false)}
			aria-label={m('social.create.close')}
		></button>
		<div
			class="relative flex w-full max-w-lg flex-col gap-6 rounded-[2.5rem] bg-surface p-6 shadow-2xl"
			transition:fly={{ y: 20 }}
		>
			<div class="flex items-center justify-between">
				<h3 class="font-headline text-xl font-black">{m('social.create.gameModalTitle')}</h3>
				<button
					type="button"
					onclick={() => (showGameSearch = false)}
					class="flex h-8 w-8 items-center justify-center rounded-full bg-surface-container"
					aria-label={m('social.create.close')}
				>
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>
			<div class="relative">
				<span
					class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant/50"
					>search</span
				>
				<input
					type="search"
					placeholder={m('social.create.searchGames')}
					aria-label={m('social.create.searchGames')}
					bind:value={gameQuery}
					oninput={onGameQuery}
					class="h-12 w-full rounded-2xl bg-surface-container pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
				/>
			</div>
			<div class="max-h-64 space-y-2 overflow-y-auto pb-4 pr-1">
				{#each gameResults as game (game.bggId)}
					<button
						type="button"
						onclick={() => {
							taggedGame = game;
							showGameSearch = false;
						}}
						class="flex w-full items-center gap-3 rounded-xl p-2 transition-colors hover:bg-surface-container"
					>
						{#if game.thumbnailUrl}
							<img
								src={game.thumbnailUrl}
								alt=""
								class="h-10 w-10 rounded-lg bg-surface-container object-cover"
							/>
						{:else}
							<span
								class="flex h-10 w-10 items-center justify-center rounded-lg bg-surface-container"
								><span class="material-symbols-outlined">casino</span></span
							>
						{/if}
						<span class="text-left">
							<span class="block text-sm font-bold leading-tight">{game.title}</span>
							{#if game.yearPublished}<span class="block text-[10px] text-on-surface-variant"
									>{game.yearPublished}</span
								>{/if}
						</span>
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Friend tagging -->
{#if showFriendSearch}
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4" transition:fade>
		<button
			type="button"
			class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (showFriendSearch = false)}
			aria-label={m('social.create.close')}
		></button>
		<div
			class="relative flex w-full max-w-lg flex-col gap-6 rounded-[2.5rem] bg-surface p-6 shadow-2xl"
			transition:fly={{ y: 20 }}
		>
			<div class="flex items-center justify-between">
				<h3 class="font-headline text-xl font-black">{m('social.create.friendsModalTitle')}</h3>
				<button
					type="button"
					onclick={() => (showFriendSearch = false)}
					class="flex h-8 w-8 items-center justify-center rounded-full bg-surface-container"
					aria-label={m('social.create.close')}
				>
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>
			<div class="max-h-80 space-y-2 overflow-y-auto pb-4 pr-1">
				{#if friendsList === null}
					<div class="flex justify-center py-8"><Spinner className="h-6 w-6" /></div>
				{:else if friendsList.length === 0}
					<p class="py-12 text-center text-sm text-on-surface-variant">
						{m('social.create.noFriends')}
					</p>
				{:else}
					{#each friendsList as friend (friend.id)}
						{@const selected = taggedFriends.some((f) => f.id === friend.id)}
						<button
							type="button"
							onclick={() => toggleFriend(friend)}
							aria-pressed={selected}
							class="flex w-full items-center justify-between rounded-2xl p-3 transition-colors {selected
								? 'bg-secondary/10'
								: 'hover:bg-surface-container'}"
						>
							<span class="flex items-center gap-3">
								<Avatar
									src={friend.avatarUrl}
									name={friend.displayName ?? friend.username}
									size="sm"
								/>
								<span class="text-sm font-bold">{friend.displayName ?? friend.username}</span>
							</span>
							<span
								class="material-symbols-outlined {selected
									? 'text-secondary'
									: 'text-on-surface-variant/30'}"
							>
								{selected ? 'check_circle' : 'add_circle'}
							</span>
						</button>
					{/each}
				{/if}
			</div>
			<Button fullWidth onclick={() => (showFriendSearch = false)}>{m('social.create.done')}</Button
			>
		</div>
	</div>
{/if}

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
