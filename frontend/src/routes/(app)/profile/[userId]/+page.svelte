<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import { friendsApi } from '$lib/api/friends';
	import type { FriendStatusValue } from '$lib/types';

	let { data } = $props();

	let localStatus = $state<FriendStatusValue | null>(null);
	let localRequestId = $state<string | null>(null);
	let loading = $state(false);

	let status = $derived(localStatus ?? data.friendStatus.status);
	let requestId = $derived(localRequestId ?? data.friendStatus.requestId);

	$effect(() => {
		// Reset local overrides when the user changes
		data.user.id; 
		localStatus = null;
		localRequestId = null;
	});

	let showCancelDialog = $state(false);

	async function handleFriendAction() {
		if (status === 'PENDING_SENT') {
			showCancelDialog = true;
			return;
		}
		loading = true;
		try {
			if (status === 'NONE') {
				const req = await friendsApi.sendRequest(data.user.id);
				localRequestId = req.id;
				localStatus = 'PENDING_SENT';
			} else if (status === 'PENDING_RECEIVED' && requestId) {
				await friendsApi.accept(requestId);
				localStatus = 'FRIENDS';
			} else if (status === 'FRIENDS') {
				await friendsApi.unfriend(data.user.id);
				localStatus = 'NONE';
				localRequestId = null;
			}
		} finally {
			loading = false;
		}
	}

	async function confirmCancel() {
		if (!requestId) return;
		showCancelDialog = false;
		loading = true;
		try {
			await friendsApi.cancel(requestId);
			localStatus = 'NONE';
			localRequestId = null;
		} finally {
			loading = false;
		}
	}

	const buttonLabel = $derived(
		status === 'NONE' ? 'Add Friend'
		: status === 'PENDING_SENT' ? 'Pending'
		: status === 'PENDING_RECEIVED' ? 'Accept Request'
		: status === 'FRIENDS' ? 'Friends'
		: null
	);

	const favorites = $derived(
		data.collection.filter((g: { isFavorited: boolean }) => g.isFavorited)
	);

	function formatTimestamp(iso: string) {
		const d = new Date(iso);
		const now = new Date();
		const diffMs = now.getTime() - d.getTime();
		const diffDays = Math.floor(diffMs / 86_400_000);
		const time = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
		if (diffDays === 0) return `Today • ${time}`;
		if (diffDays === 1) return `Yesterday • ${time}`;
		if (diffDays < 7) return `${diffDays} days ago • ${time}`;
		return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ` • ${time}`;
	}
</script>

<svelte:head><title>{data.user.displayName ?? data.user.username} — Meeple</title></svelte:head>

<div class="flex flex-col items-center gap-6 mb-8 pt-2">
	<div class="rotate-2 rounded-2xl overflow-hidden w-28 h-28 shadow-[0_12px_32px_rgba(0,0,0,0.10)] ring-4 ring-surface">
		<Avatar
			src={data.user.avatarUrl}
			name={data.user.displayName ?? data.user.username}
			className="w-full h-full object-cover scale-105 rounded-none"
		/>
	</div>
	<div class="text-center">
		<h1 class="text-xl font-extrabold font-headline">{data.user.displayName ?? data.user.username}</h1>
		<p class="text-sm text-on-surface-variant">@{data.user.username}</p>
	</div>
	{#if data.user.bio}
		<p class="text-sm text-center text-on-surface-variant max-w-xs">{data.user.bio}</p>
	{/if}
	{#if data.user.location}
		<p class="text-xs text-on-surface-variant flex items-center gap-1">
			<span class="material-symbols-outlined text-base">location_on</span>
			{data.user.location}
		</p>
	{/if}
</div>

{#if status !== 'BLOCKED' && buttonLabel}
	<Button fullWidth variant={status === 'FRIENDS' ? 'secondary' : 'primary'} disabled={loading} onclick={handleFriendAction}>
		{buttonLabel}
	</Button>
{/if}

<!-- Cancel friend request dialog -->
{#if showCancelDialog}
	<div class="fixed inset-0 z-50 flex items-end justify-center pb-8 px-4">
		<button class="absolute inset-0 bg-black/40" onclick={() => (showCancelDialog = false)} aria-label="Close"></button>
		<div class="relative w-full max-w-sm bg-surface rounded-2xl shadow-xl p-6 space-y-4">
			<h3 class="text-base font-bold text-on-surface">Cancel Friend Request?</h3>
			<p class="text-sm text-on-surface-variant">
				Remove your pending request to <span class="font-semibold">{data.user.displayName ?? data.user.username}</span>?
			</p>
			<div class="flex gap-3">
				<Button fullWidth variant="secondary" onclick={() => (showCancelDialog = false)}>Keep</Button>
				<Button fullWidth onclick={confirmCancel}>Cancel Request</Button>
			</div>
		</div>
	</div>
{/if}

{#if status === 'FRIENDS' && data.collection.length > 0}
	<!-- Favorite Games -->
	{#if favorites.length > 0}
		<section class="mt-8 mb-6">
			<h3 class="text-lg font-extrabold font-headline tracking-tight mb-4">Favorite Games</h3>
			<div class="flex gap-4 overflow-x-auto hide-scrollbar -mx-4 px-4 pb-3">
				{#each favorites as ug (ug.id)}
					<a href="/library/{ug.game.id}" class="flex-shrink-0 w-32 group">
						<div class="h-44 bg-surface-container rounded-2xl overflow-hidden shadow-[0_8px_24px_rgba(0,0,0,0.06)] transition-transform duration-300 group-hover:scale-[1.02]">
							{#if ug.game.thumbnailUrl}
								<img src={ug.game.thumbnailUrl} alt={ug.game.title} class="w-full h-full object-cover" loading="lazy" />
							{:else}
								<div class="w-full h-full flex items-center justify-center">
									<span class="material-symbols-outlined text-3xl text-on-surface-variant opacity-30">casino</span>
								</div>
							{/if}
						</div>
						<p class="text-sm font-bold text-on-surface line-clamp-1 mt-2">{ug.game.title}</p>
					</a>
				{/each}
			</div>
		</section>
	{/if}

	<!-- Recent Activity -->
	{#if data.activity.length > 0}
		<section class="mb-8">
			<h3 class="text-lg font-extrabold font-headline tracking-tight mb-4">Recent Activity</h3>
			<div class="space-y-3">
				{#each data.activity.slice(0, 10) as item (item.id)}
					<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-2xl">
						<div class="w-10 h-10 rounded-xl overflow-hidden flex-shrink-0 bg-surface-container">
							{#if item.type === 'post' && item.imageUrls && item.imageUrls.length > 0}
								<img src={item.imageUrls[0]} alt="Post" class="w-full h-full object-cover" loading="lazy" />
							{:else if item.game?.thumbnailUrl}
								<img src={item.game.thumbnailUrl} alt={item.game.title} class="w-full h-full object-cover" loading="lazy" />
							{:else}
								<div class="w-full h-full flex items-center justify-center opacity-40">
									<span class="material-symbols-outlined text-sm">{item.type === 'event' ? 'event' : item.type === 'post' ? 'image' : 'casino'}</span>
								</div>
							{/if}
						</div>
						<div class="flex-1 min-w-0">
							<p class="text-sm font-semibold text-on-surface line-clamp-1">
								{#if item.type === 'event'}
									{item.eventTitle}
								{:else if item.type === 'post'}
									{item.caption ?? 'Shared a memory'}
								{:else}
									Played {item.game?.title}
								{/if}
							</p>
							<p class="text-xs text-on-surface-variant">{formatTimestamp(item.playedAt)}</p>
						</div>
						<span class="text-[10px] font-label font-black uppercase tracking-widest px-1.5 py-0.5 rounded-md {item.type === 'event' ? 'bg-secondary text-white' : item.type === 'post' ? 'bg-tertiary text-white' : 'bg-primary text-white'}">
							{item.type}
						</span>
					</div>
				{/each}
			</div>
		</section>
	{/if}
{/if}
