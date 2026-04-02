<script lang="ts">
	import { onMount } from 'svelte';
	import { adminApi } from '$lib/api/admin';
	import { currentUser } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import type { RulebookQueueItem, RuleNoteQueueItem } from '$lib/types';

	let activeTab: 'rulebooks' | 'notes' = $state('rulebooks');

	// ── Rulebook queue ─────────────────────────────────────────────────────────
	let items: RulebookQueueItem[] = $state([]);
	let loading = $state(true);
	let page = $state(0);
	let hasMore = $state(false);
	let rejectingId: string | null = $state(null);
	let rejectReason = $state('');
	let processingId: string | null = $state(null);

	// ── Rule note queue ────────────────────────────────────────────────────────
	let noteItems: RuleNoteQueueItem[] = $state([]);
	let notesLoading = $state(false);
	let notesPage = $state(0);
	let notesHasMore = $state(false);
	let noteProcessingId: string | null = $state(null);
	let rejectingNoteId: string | null = $state(null);
	let noteRejectReason = $state('');

	onMount(async () => {
		if (!$currentUser?.isAdmin) {
			goto('/');
			return;
		}
		await loadPage(0);
	});

	async function loadPage(p: number) {
		loading = true;
		try {
			const res = await adminApi.getRulebookQueue('pending_review', p, 20);
			items = p === 0 ? (res.content ?? []) : [...items, ...(res.content ?? [])];
			page = res.number;
			hasMore = !res.last;
		} catch {
			toast.error('Failed to load queue');
		} finally {
			loading = false;
		}
	}

	async function approve(id: string) {
		processingId = id;
		try {
			await adminApi.approveRulebook(id);
			items = items.filter((i) => i.id !== id);
			toast.success('Rulebook approved — ingestion started');
		} catch {
			toast.error('Failed to approve');
		} finally {
			processingId = null;
		}
	}

	function startReject(id: string) {
		rejectingId = id;
		rejectReason = '';
	}

	async function confirmReject() {
		if (!rejectingId) return;
		processingId = rejectingId;
		try {
			await adminApi.rejectRulebook(rejectingId, rejectReason || undefined);
			items = items.filter((i) => i.id !== rejectingId);
			toast.success('Rulebook rejected');
		} catch {
			toast.error('Failed to reject');
		} finally {
			processingId = null;
			rejectingId = null;
			rejectReason = '';
		}
	}

	function formatDate(iso: string) {
		return new Date(iso).toLocaleDateString(undefined, {
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	async function loadNotesPage(p: number) {
		notesLoading = true;
		try {
			const res = await adminApi.getRuleNoteQueue(p, 20);
			noteItems = p === 0 ? (res.content ?? []) : [...noteItems, ...(res.content ?? [])];
			notesPage = res.number;
			notesHasMore = !res.last;
		} catch {
			toast.error('Failed to load notes queue');
		} finally {
			notesLoading = false;
		}
	}

	async function approveNote(id: string) {
		noteProcessingId = id;
		try {
			await adminApi.approveRuleNote(id);
			noteItems = noteItems.filter((n) => n.id !== id);
			toast.success('Note approved');
		} catch {
			toast.error('Failed to approve note');
		} finally {
			noteProcessingId = null;
		}
	}

	function startRejectNote(id: string) {
		rejectingNoteId = id;
		noteRejectReason = '';
	}

	async function confirmRejectNote() {
		if (!rejectingNoteId) return;
		noteProcessingId = rejectingNoteId;
		try {
			await adminApi.rejectRuleNote(rejectingNoteId, noteRejectReason || undefined);
			noteItems = noteItems.filter((n) => n.id !== rejectingNoteId);
			toast.success('Note rejected');
		} catch {
			toast.error('Failed to reject note');
		} finally {
			noteProcessingId = null;
			rejectingNoteId = null;
			noteRejectReason = '';
		}
	}

	$effect(() => {
		if (activeTab === 'notes' && noteItems.length === 0 && !notesLoading) {
			loadNotesPage(0);
		}
	});

	const sourceLabel: Record<string, string> = {
		rule_book_org: 'rule-book.org',
		onj: '1jour1jeu',
		user: 'User',
		admin: 'Admin'
	};
</script>

<svelte:head><title>Review Queue — Admin</title></svelte:head>

<div class="py-4 space-y-6 pb-24">
	<!-- Header -->
	<div class="flex items-center gap-4">
		<button 
			onclick={() => history.back()}
			class="w-10 h-10 rounded-xl bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
			aria-label="Back"
		>
			<span class="material-symbols-outlined text-[22px]">arrow_back</span>
		</button>
		<div class="flex-1">
			<p class="text-[10px] font-bold uppercase tracking-widest text-primary mb-0.5">Admin</p>
			<h1 class="text-2xl font-extrabold font-headline">Review Queue</h1>
		</div>
		<div class="w-10 h-10 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
			<span class="material-symbols-outlined text-[22px]">rate_review</span>
		</div>
	</div>

	<!-- Tabs -->
	<div class="flex gap-2 bg-surface-container-low rounded-2xl p-1">
		<button
			onclick={() => { activeTab = 'rulebooks'; }}
			class="flex-1 py-2 rounded-xl text-sm font-bold transition-all {activeTab === 'rulebooks' ? 'bg-surface text-on-surface shadow-sm' : 'text-on-surface-variant'}"
		>Rulebooks</button>
		<button
			onclick={() => { activeTab = 'notes'; }}
			class="flex-1 py-2 rounded-xl text-sm font-bold transition-all {activeTab === 'notes' ? 'bg-surface text-on-surface shadow-sm' : 'text-on-surface-variant'}"
		>Rule Notes</button>
	</div>

	{#if activeTab === 'rulebooks'}
	{#if loading && items.length === 0}
		<!-- Skeleton -->
		<div class="space-y-3">
			{#each [1, 2, 3] as _}
				<div class="bg-surface-container-low rounded-2xl p-4 animate-pulse space-y-3">
					<div class="h-4 w-2/3 rounded-full bg-surface-container-high"></div>
					<div class="h-3 w-1/3 rounded-full bg-surface-container-high"></div>
					<div class="flex gap-2">
						<div class="h-9 flex-1 rounded-xl bg-surface-container-high"></div>
						<div class="h-9 flex-1 rounded-xl bg-surface-container-high"></div>
					</div>
				</div>
			{/each}
		</div>

	{:else if items.length === 0}
		<div class="bg-surface-container-low rounded-3xl p-10 text-center">
			<span class="material-symbols-outlined text-4xl text-primary/20 block mb-3">check_circle</span>
			<p class="font-bold text-on-surface">Queue is empty</p>
			<p class="text-xs text-on-surface-variant mt-1">No pending rulebooks to review.</p>
		</div>

	{:else}
		<div class="space-y-3">
			{#each items as item (item.id)}
				<div class="bg-surface-container-low rounded-2xl p-4 space-y-3">
					<!-- Game info -->
					<div class="flex items-start justify-between gap-2">
						<div class="min-w-0">
							<a href="/library/{item.gameId}" class="font-bold text-on-surface leading-tight line-clamp-1 hover:text-primary transition-colors">
								{item.gameName}
							</a>
							<div class="flex items-center gap-2 mt-1 flex-wrap">
								<span class="text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full bg-surface-container-high text-on-surface-variant">
									{sourceLabel[item.source] ?? item.source}
								</span>
								{#if item.uploaderUsername}
									<span class="text-xs text-on-surface-variant">by @{item.uploaderUsername}</span>
								{/if}
								<span class="text-xs text-on-surface-variant">{formatDate(item.createdAt)}</span>
							</div>
						</div>
						{#if item.queuePosition !== null}
							<span class="text-[10px] font-black text-primary bg-primary/10 px-2 py-1 rounded-lg flex-shrink-0">
								#{item.queuePosition + 1}
							</span>
						{/if}
					</div>

					<!-- PDF link -->
					{#if item.fileUrl}
						<a
							href={item.fileUrl}
							target="_blank"
							rel="noopener noreferrer"
							class="flex items-center gap-2 text-xs text-primary font-medium"
						>
							<span class="material-symbols-outlined text-[16px]">picture_as_pdf</span>
							View PDF
						</a>
					{/if}

					<!-- Actions -->
					<div class="flex gap-2">
						<button
							onclick={() => approve(item.id)}
							disabled={processingId === item.id}
							class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-primary text-on-primary text-sm font-bold disabled:opacity-50 transition-opacity"
						>
							{#if processingId === item.id}
								<span class="material-symbols-outlined text-[16px] animate-spin">progress_activity</span>
							{:else}
								<span class="material-symbols-outlined text-[16px]">check</span>
							{/if}
							Approve
						</button>
						<button
							onclick={() => startReject(item.id)}
							disabled={processingId === item.id}
							class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-error-container text-on-error-container text-sm font-bold disabled:opacity-50 transition-opacity"
						>
							<span class="material-symbols-outlined text-[16px]">close</span>
							Reject
						</button>
					</div>
				</div>
			{/each}
		</div>

		{#if hasMore}
			<button
				onclick={() => loadPage(page + 1)}
				disabled={loading}
				class="w-full py-3 rounded-2xl bg-surface-container-high text-on-surface text-sm font-bold disabled:opacity-50"
			>
				{loading ? 'Loading…' : 'Load more'}
			</button>
		{/if}
	{/if}

	{:else}

	<!-- Rule Notes Tab -->
	{#if notesLoading && noteItems.length === 0}
		<div class="space-y-3">
			{#each [1, 2, 3] as _}
				<div class="bg-surface-container-low rounded-2xl p-4 animate-pulse space-y-3">
					<div class="h-4 w-2/3 rounded-full bg-surface-container-high"></div>
					<div class="h-3 w-full rounded-full bg-surface-container-high"></div>
					<div class="flex gap-2">
						<div class="h-9 flex-1 rounded-xl bg-surface-container-high"></div>
						<div class="h-9 flex-1 rounded-xl bg-surface-container-high"></div>
					</div>
				</div>
			{/each}
		</div>

	{:else if noteItems.length === 0}
		<div class="bg-surface-container-low rounded-3xl p-10 text-center">
			<span class="material-symbols-outlined text-4xl text-primary/20 block mb-3">check_circle</span>
			<p class="font-bold text-on-surface">Queue is empty</p>
			<p class="text-xs text-on-surface-variant mt-1">No pending rule notes to review.</p>
		</div>

	{:else}
		<div class="space-y-3">
			{#each noteItems as note (note.id)}
				<div class="bg-surface-container-low rounded-2xl p-4 space-y-3">
					<div class="flex items-start justify-between gap-2">
						<div class="min-w-0">
							<a href="/library/{note.gameId}" class="font-bold text-on-surface leading-tight line-clamp-1 hover:text-primary transition-colors">
								{note.gameName}
							</a>
							<div class="flex items-center gap-2 mt-1">
								<span class="text-xs text-on-surface-variant">by @{note.submittedByUsername}</span>
								<span class="text-xs text-on-surface-variant">{formatDate(note.createdAt)}</span>
							</div>
						</div>
					</div>
					<p class="text-sm text-on-surface leading-relaxed whitespace-pre-line bg-surface-container-high/50 rounded-xl p-3">{note.content}</p>
					<div class="flex gap-2">
						<button
							onclick={() => approveNote(note.id)}
							disabled={noteProcessingId === note.id}
							class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-primary text-on-primary text-sm font-bold disabled:opacity-50 transition-opacity"
						>
							{#if noteProcessingId === note.id}
								<span class="material-symbols-outlined text-[16px] animate-spin">progress_activity</span>
							{:else}
								<span class="material-symbols-outlined text-[16px]">check</span>
							{/if}
							Approve
						</button>
						<button
							onclick={() => startRejectNote(note.id)}
							disabled={noteProcessingId === note.id}
							class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-error-container text-on-error-container text-sm font-bold disabled:opacity-50 transition-opacity"
						>
							<span class="material-symbols-outlined text-[16px]">close</span>
							Reject
						</button>
					</div>
				</div>
			{/each}
		</div>

		{#if notesHasMore}
			<button
				onclick={() => loadNotesPage(notesPage + 1)}
				disabled={notesLoading}
				class="w-full py-3 rounded-2xl bg-surface-container-high text-on-surface text-sm font-bold disabled:opacity-50"
			>
				{notesLoading ? 'Loading…' : 'Load more'}
			</button>
		{/if}
	{/if}

	{/if}
</div>

<!-- Reject reason sheet -->
{#if rejectingId}
	<div class="fixed inset-0 z-50 flex items-end">
		<button aria-label="Close" class="absolute inset-0 bg-black/40 backdrop-blur-sm" onclick={() => (rejectingId = null)}></button>
		<div class="relative w-full bg-surface rounded-t-3xl p-6 space-y-4 max-w-lg mx-auto">
			<h3 class="font-bold text-on-surface">Reject rulebook</h3>
			<p class="text-xs text-on-surface-variant">Optional — leave blank to reject without a reason.</p>
			<textarea
				bind:value={rejectReason}
				placeholder="Reason (e.g. wrong game, unreadable scan…)"
				rows="3"
				class="w-full bg-surface-container-low rounded-xl px-3 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 resize-none focus:outline-none focus:ring-1 focus:ring-error"
			></textarea>
			<div class="flex gap-3">
				<button
					onclick={() => (rejectingId = null)}
					class="flex-1 py-3 rounded-2xl bg-surface-container-high text-on-surface font-bold text-sm"
				>
					Cancel
				</button>
				<button
					onclick={confirmReject}
					disabled={processingId !== null}
					class="flex-1 py-3 rounded-2xl bg-error text-on-error font-bold text-sm disabled:opacity-50"
				>
					{processingId ? 'Rejecting…' : 'Confirm Reject'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Reject note sheet -->
{#if rejectingNoteId}
	<div class="fixed inset-0 z-50 flex items-end">
		<button aria-label="Close" class="absolute inset-0 bg-black/40 backdrop-blur-sm" onclick={() => (rejectingNoteId = null)}></button>
		<div class="relative w-full bg-surface rounded-t-3xl p-6 space-y-4 max-w-lg mx-auto">
			<h3 class="font-bold text-on-surface">Reject rule note</h3>
			<p class="text-xs text-on-surface-variant">Optional — leave blank to reject without a reason.</p>
			<textarea
				bind:value={noteRejectReason}
				placeholder="Reason (e.g. incorrect, already covered…)"
				rows="3"
				class="w-full bg-surface-container-low rounded-xl px-3 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 resize-none focus:outline-none focus:ring-1 focus:ring-error"
			></textarea>
			<div class="flex gap-3">
				<button
					onclick={() => (rejectingNoteId = null)}
					class="flex-1 py-3 rounded-2xl bg-surface-container-high text-on-surface font-bold text-sm"
				>
					Cancel
				</button>
				<button
					onclick={confirmRejectNote}
					disabled={noteProcessingId !== null}
					class="flex-1 py-3 rounded-2xl bg-error text-on-error font-bold text-sm disabled:opacity-50"
				>
					{noteProcessingId ? 'Rejecting…' : 'Confirm Reject'}
				</button>
			</div>
		</div>
	</div>
{/if}
