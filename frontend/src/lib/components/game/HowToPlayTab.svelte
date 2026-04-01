<script lang="ts">
	import { onMount } from 'svelte';
	import { rulebookApi } from '$lib/api/rulebook';
	import { adminApi } from '$lib/api/admin';
	import { currentUser } from '$lib/stores/auth';
	import { toast } from 'svelte-sonner';

	interface Props {
		gameId: string;
		onOpenAssistant: () => void;
	}
	let { gameId, onOpenAssistant }: Props = $props();

	const isAdmin = $derived($currentUser?.isAdmin ?? false);

	type RulebookState = 'loading' | 'no_rulebook' | 'generating' | 'pending_review' | 'ready' | 'error';
	let rulebookState: RulebookState = $state('loading');
	let generating: boolean = $state(false);
	let uploading: boolean = $state(false);
	let myQueuePosition: number | null = $state(null);

	// File input ref for user upload
	let fileInput: HTMLInputElement = $state() as HTMLInputElement;
	let adminFileInput: HTMLInputElement = $state() as HTMLInputElement;

	onMount(async () => {
		try {
			const status = await rulebookApi.getStatus(gameId);
			if (status.hasRulebook) {
				rulebookState = 'ready';
			} else if (status.myStatus === 'pending_review') {
				rulebookState = 'pending_review';
				myQueuePosition = status.myQueuePosition;
			} else {
				rulebookState = 'no_rulebook';
			}
		} catch {
			rulebookState = 'error';
		}
	});

	async function handleGenerate() {
		generating = true;
		try {
			const result = await rulebookApi.generate(gameId);
			if (result.status === 'generating') {
				rulebookState = 'generating';
			} else if (result.status === 'already_done') {
				rulebookState = 'ready';
			}
			// not_found stays on no_rulebook — show upload option
		} catch {
			toast.error('Could not fetch rulebook');
		} finally {
			generating = false;
		}
	}

	async function handleUserUpload(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		uploading = true;
		try {
			const result = await rulebookApi.upload(gameId, file);
			if (result.status === 'queued') {
				rulebookState = 'pending_review';
				myQueuePosition = result.queuePosition ?? null;
				toast.success('PDF submitted! An admin will review it shortly.');
			} else if (result.status === 'already_done') {
				rulebookState = 'ready';
			}
		} catch {
			toast.error('Upload failed. File must be a PDF under 25 MB.');
		} finally {
			uploading = false;
			fileInput.value = '';
		}
	}

	async function handleAdminUpload(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		uploading = true;
		try {
			await adminApi.uploadRulebookForGame(gameId, file);
			rulebookState = 'generating';
			toast.success('Uploading and ingesting…');
		} catch {
			toast.error('Admin upload failed.');
		} finally {
			uploading = false;
			adminFileInput.value = '';
		}
	}
</script>

<div class="py-4 space-y-8 pb-12">
	<!-- Hero Header -->
	<div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-primary/10 via-background to-secondary/5 border border-outline-variant/10 p-6">
		<div class="relative z-10 flex items-start justify-between">
			<div class="space-y-1">
				<div class="flex items-center gap-2 text-primary font-black uppercase tracking-widest text-[10px]">
					<span class="material-symbols-outlined text-[16px]">auto_awesome</span>
					AI Rule Extraction
				</div>
				<h2 class="text-xl font-extrabold text-on-surface">How to Play</h2>
				<p class="text-xs text-on-surface-variant max-w-[240px] leading-relaxed">
					Follow these essential rules to get the game started quickly.
				</p>
			</div>
			<div class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-primary/40 rotate-12">
				<span class="material-symbols-outlined text-[40px]">menu_book</span>
			</div>
		</div>
		<div class="absolute -right-4 -bottom-4 w-32 h-32 bg-primary/5 rounded-full blur-3xl"></div>
	</div>

	<!-- States -->
	{#if rulebookState === 'loading'}
		<div class="space-y-6">
			{#each [1, 2, 3] as _}
				<div class="space-y-3 animate-pulse">
					<div class="flex items-center gap-3">
						<div class="w-10 h-10 rounded-xl bg-surface-container-high"></div>
						<div class="h-4 w-32 rounded-full bg-surface-container-high"></div>
					</div>
					<div class="pl-13 space-y-2">
						<div class="h-3 rounded-full bg-surface-container-low/50 w-full"></div>
						<div class="h-3 rounded-full bg-surface-container-low/50 w-5/6"></div>
					</div>
				</div>
			{/each}
		</div>

	{:else if rulebookState === 'no_rulebook'}
		<div class="rounded-3xl border border-outline-variant/10 bg-surface-container-low/30 p-6 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-on-surface-variant/40">
				<span class="material-symbols-outlined text-[36px]">find_in_page</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">No rulebook yet</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					Try auto-fetching from rule-book.org, or upload the PDF yourself.
				</p>
			</div>

			<!-- Auto-fetch -->
			<button
				onclick={handleGenerate}
				disabled={generating || uploading}
				class="w-full flex items-center justify-center gap-2 px-5 py-2.5 rounded-2xl bg-primary text-on-primary text-sm font-bold disabled:opacity-50 transition-opacity"
			>
				{#if generating}
					<span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
					Fetching…
				{:else}
					<span class="material-symbols-outlined text-[18px]">bolt</span>
					Generate Rules
				{/if}
			</button>

			<!-- User upload -->
			<div class="w-full">
				<input
					bind:this={fileInput}
					type="file"
					accept="application/pdf"
					class="hidden"
					onchange={handleUserUpload}
				/>
				<button
					onclick={() => fileInput.click()}
					disabled={generating || uploading}
					class="w-full flex items-center justify-center gap-2 px-5 py-2.5 rounded-2xl bg-surface-container-high text-on-surface text-sm font-bold disabled:opacity-50 transition-opacity"
				>
					{#if uploading}
						<span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
						Uploading…
					{:else}
						<span class="material-symbols-outlined text-[18px]">upload_file</span>
						Upload PDF
					{/if}
				</button>
				<p class="text-[10px] text-on-surface-variant text-center mt-1.5">PDF only · max 25 MB · goes to admin review</p>
			</div>
		</div>

	{:else if rulebookState === 'generating'}
		<div class="rounded-3xl border border-primary/20 bg-primary/5 p-8 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
				<span class="material-symbols-outlined text-[36px] animate-spin">progress_activity</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">Generating rules…</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					We found the rulebook PDF and are processing it. This usually takes under a minute. Check back shortly.
				</p>
			</div>
		</div>

	{:else if rulebookState === 'pending_review'}
		<div class="rounded-3xl border border-secondary/20 bg-secondary/5 p-8 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-secondary/10 flex items-center justify-center text-secondary">
				<span class="material-symbols-outlined text-[36px]">hourglass_top</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">PDF under review</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					Your upload is in the queue{myQueuePosition !== null ? ` (#${myQueuePosition + 1})` : ''}. Rules will appear once an admin approves it.
				</p>
			</div>
		</div>

	{:else if rulebookState === 'ready'}
		<div class="rounded-3xl border border-outline-variant/10 bg-surface-container-low/30 p-8 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
				<span class="material-symbols-outlined text-[36px]">check_circle</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">Rulebook ready</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					The rulebook has been indexed. Use the AI Assistant below to ask any question about the rules.
				</p>
			</div>
		</div>

	{:else if rulebookState === 'error'}
		<p class="text-center text-xs text-error py-8">Failed to load rulebook status. Try refreshing.</p>
	{/if}

	<!-- Admin upload (always visible to admins) -->
	{#if isAdmin}
		<div class="rounded-2xl border border-outline-variant/10 bg-surface-container-low/20 p-4">
			<p class="text-[10px] font-bold uppercase tracking-widest text-primary mb-3">Admin</p>
			<input
				bind:this={adminFileInput}
				type="file"
				accept="application/pdf"
				class="hidden"
				onchange={handleAdminUpload}
			/>
			<button
				onclick={() => adminFileInput.click()}
				disabled={uploading}
				class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-primary/10 text-primary text-sm font-bold disabled:opacity-50"
			>
				{#if uploading}
					<span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
					Uploading…
				{:else}
					<span class="material-symbols-outlined text-[18px]">admin_panel_settings</span>
					Override: Upload PDF (auto-approve)
				{/if}
			</button>
		</div>
	{/if}

	<!-- AI Assistant Call-to-action -->
	<button
		onclick={onOpenAssistant}
		class="w-full bg-tertiary-container/30 rounded-3xl p-6 border border-tertiary/10 flex flex-col items-center text-center gap-3 mt-4 hover:bg-tertiary-container/40 transition-colors"
	>
		<div class="w-12 h-12 rounded-full bg-tertiary/10 flex items-center justify-center text-tertiary">
			<span class="material-symbols-outlined">smart_toy</span>
		</div>
		<div class="space-y-1">
			<h4 class="font-bold text-on-tertiary-container">Still have questions?</h4>
			<p class="text-[11px] text-on-tertiary-container/70 leading-relaxed px-4">
				Our AI Assistant has read the full rulebook and can answer specific edge cases.
			</p>
		</div>
	</button>
</div>

<style>
	.pl-13 {
		padding-left: 3.25rem;
	}
</style>
