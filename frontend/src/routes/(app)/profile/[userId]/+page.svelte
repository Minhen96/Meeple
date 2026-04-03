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

	let currentView = $state<'activity' | 'owned' | 'favorites' | 'played' | 'friends'>('activity');

	const owned = $derived(data.collection.filter((ug: any) => ug.isOwned));
	const favorites = $derived(data.collection.filter((ug: any) => ug.isFavorited));
	const played = $derived(data.collection.filter((ug: any) => ug.playCount > 0));

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

<div class="flex flex-col items-center gap-6 mb-6 pt-2">
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
</div>

{#if status !== 'BLOCKED' && buttonLabel}
	<div class="mb-8">
		<Button fullWidth variant={status === 'FRIENDS' ? 'secondary' : 'primary'} disabled={loading} onclick={handleFriendAction}>
			{buttonLabel}
		</Button>
	</div>
{/if}

<!-- Collection Summary Row -->
<div class="grid grid-cols-4 gap-3 mb-8">
	<button 
		onclick={() => currentView = currentView === 'owned' ? 'activity' : 'owned'}
		class="flex flex-col items-center gap-2 p-3 rounded-2xl transition-all border
			{currentView === 'owned' ? 'bg-primary/10 border-primary shadow-sm' : 'bg-surface-container-low border-transparent active:scale-95'}"
	>
		<span class="material-symbols-outlined text-2xl {currentView === 'owned' ? 'text-primary' : 'text-on-surface-variant'}">inventory_2</span>
		<div class="text-center">
			<p class="text-xs font-bold {currentView === 'owned' ? 'text-primary' : 'text-on-surface'}">{owned.length}</p>
			<p class="text-[10px] uppercase tracking-tighter opacity-60">Owned</p>
		</div>
	</button>

	<button 
		onclick={() => currentView = currentView === 'favorites' ? 'activity' : 'favorites'}
		class="flex flex-col items-center gap-2 p-3 rounded-2xl transition-all border
			{currentView === 'favorites' ? 'bg-secondary/10 border-secondary shadow-sm' : 'bg-surface-container-low border-transparent active:scale-95'}"
	>
		<span class="material-symbols-outlined text-2xl {currentView === 'favorites' ? 'text-secondary' : 'text-on-surface-variant'}">favorite</span>
		<div class="text-center">
			<p class="text-xs font-bold {currentView === 'favorites' ? 'text-secondary' : 'text-on-surface'}">{favorites.length}</p>
			<p class="text-[10px] uppercase tracking-tighter opacity-60">Favs</p>
		</div>
	</button>

	<button 
		onclick={() => currentView = currentView === 'played' ? 'activity' : 'played'}
		class="flex flex-col items-center gap-2 p-3 rounded-2xl transition-all border
			{currentView === 'played' ? 'bg-tertiary/10 border-tertiary shadow-sm' : 'bg-surface-container-low border-transparent active:scale-95'}"
	>
		<span class="material-symbols-outlined text-2xl {currentView === 'played' ? 'text-tertiary' : 'text-on-surface-variant'}">history_edu</span>
		<div class="text-center">
			<p class="text-xs font-bold {currentView === 'played' ? 'text-tertiary' : 'text-on-surface'}">{played.length}</p>
			<p class="text-[10px] uppercase tracking-tighter opacity-60">Played</p>
		</div>
	</button>

	<button 
		onclick={() => currentView = currentView === 'friends' ? 'activity' : 'friends'}
		class="flex flex-col items-center gap-2 p-3 rounded-2xl transition-all border
			{currentView === 'friends' ? 'bg-outline/10 border-outline shadow-sm' : 'bg-surface-container-low border-transparent active:scale-95'}"
	>
		<span class="material-symbols-outlined text-2xl {currentView === 'friends' ? 'text-outline-variant' : 'text-on-surface-variant'}">group</span>
		<div class="text-center">
			<p class="text-xs font-bold text-on-surface">?</p>
			<p class="text-[10px] uppercase tracking-tighter opacity-60">Friends</p>
		</div>
	</button>
</div>

<!-- Content Area -->
<div class="pb-24">
	{#if currentView === 'activity'}
		<h3 class="text-lg font-extrabold font-headline tracking-tight mb-4">Recent Activity</h3>
		{#if data.activity.length > 0}
			<div class="space-y-3">
				{#each data.activity.slice(0, 15) as item (item.id)}
					<a href={item.type === 'post' ? `/posts/${item.id}` : item.type === 'event' ? `/events/${item.eventId}` : `/library/${item.game?.id}`} 
						class="flex items-center gap-3 p-3 bg-surface-container-low rounded-2xl active:scale-[0.98] transition-transform">
						<div class="w-12 h-12 rounded-xl overflow-hidden flex-shrink-0 bg-surface-container">
							{#if item.type === 'post' && item.imageUrls && item.imageUrls.length > 0}
								<img src={item.imageUrls[0]} alt="Post" class="w-full h-full object-cover" />
							{:else if item.game?.thumbnailUrl}
								<img src={item.game.thumbnailUrl} alt={item.game.title} class="w-full h-full object-cover" />
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
						<span class="text-[10px] font-label font-black uppercase tracking-widest px-2 py-1 rounded-lg {item.type === 'event' ? 'bg-secondary/20 text-secondary' : item.type === 'post' ? 'bg-tertiary/20 text-tertiary' : 'bg-primary/20 text-primary'}">
							{item.type}
						</span>
					</a>
				{/each}
			</div>
		{:else}
			<div class="text-center py-12 opacity-40">
				<span class="material-symbols-outlined text-4xl mb-2">history</span>
				<p class="text-sm">No activity yet</p>
			</div>
		{/if}
	{:else if currentView === 'friends'}
		<h3 class="text-lg font-extrabold font-headline tracking-tight mb-4">Friends</h3>
		<div class="text-center py-12 opacity-40 bg-surface-container-low rounded-3xl">
			<span class="material-symbols-outlined text-4xl mb-2">group</span>
			<p class="text-sm">Friends list coming soon</p>
			<button onclick={() => currentView = 'activity'} class="mt-4 text-xs font-bold text-primary uppercase tracking-widest">Back to Activity</button>
		</div>
	{:else}
		{@const currentList = currentView === 'owned' ? owned : currentView === 'favorites' ? favorites : played}
		{@const title = currentView === 'owned' ? 'Owned Games' : currentView === 'favorites' ? 'Favorite Games' : 'Played Games'}
		
		<div class="flex items-center justify-between mb-4">
			<h3 class="text-lg font-extrabold font-headline tracking-tight">{title}</h3>
			<button onclick={() => currentView = 'activity'} class="text-xs font-bold text-primary uppercase tracking-widest">Activity</button>
		</div>

		{#if currentList.length > 0}
			<div class="grid grid-cols-3 gap-3">
				{#each currentList as ug (ug.id)}
					<a href="/library/{ug.game.id}" class="group">
						<div class="aspect-[3/4] bg-surface-container rounded-xl overflow-hidden shadow-sm transition-transform group-hover:scale-[1.02]">
							{#if ug.game.thumbnailUrl}
								<img src={ug.game.thumbnailUrl} alt={ug.game.title} class="w-full h-full object-cover" />
							{:else}
								<div class="w-full h-full flex items-center justify-center opacity-30">
									<span class="material-symbols-outlined text-2xl">casino</span>
								</div>
							{/if}
						</div>
						<p class="text-[10px] font-bold text-on-surface line-clamp-1 mt-1 px-1">{ug.game.title}</p>
					</a>
				{/each}
			</div>
		{:else}
			<div class="text-center py-12 opacity-40 bg-surface-container-low rounded-3xl">
				<span class="material-symbols-outlined text-4xl mb-2">view_module</span>
				<p class="text-sm">Collection is empty</p>
			</div>
		{/if}
	{/if}
</div>

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
