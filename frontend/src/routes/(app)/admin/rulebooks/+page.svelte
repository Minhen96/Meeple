<script lang="ts">
	import { onMount } from 'svelte';
	import { adminApi } from '$lib/api/admin';
	import { currentUser } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import type { RulebookQueueItem } from '$lib/types';

	let items: RulebookQueueItem[] = $state([]);
	let loading = $state(true);
	let page = $state(0);
	let hasMore = $state(false);
	let rejectingId: string | null = $state(null);
	let rejectReason = $state('');
	let processingId: string | null = $state(null);

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
			items = p === 0 ? res.content : [...items, ...res.content];
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

	const sourceLabel: Record<string, string> = {
		rule_book_org: 'rule-book.org',
		onj: '1jour1jeu',
		user: 'User',
		admin: 'Admin'
	};
</script>

<svelte:head><title>Rulebook Queue — Admin</title></svelte:head>

<div class="py-4 space-y-6 pb-24">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<div>
			<p class="text-[10px] font-bold uppercase tracking-widest text-primary mb-0.5">Admin</p>
			<h1 class="text-2xl font-extrabold font-headline">Rulebook Queue</h1>
		</div>
		<div class="w-10 h-10 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
			<span class="material-symbols-outlined text-[22px]">rate_review</span>
		</div>
	</div>

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
</div>

<!-- Reject reason sheet -->
{#if rejectingId}
	<div class="fixed inset-0 z-50 flex items-end">
		<button class="absolute inset-0 bg-black/40 backdrop-blur-sm" onclick={() => (rejectingId = null)}></button>
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
