<script lang="ts">
	import { onMount } from 'svelte';
	import { friendsApi } from '$lib/api/friends';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import type { User, FriendRequest } from '$lib/types';

	let tab = $state<'discover' | 'requests' | 'friends'>('discover');
	let searchQuery = $state('');
	let searchResults = $state<User[]>([]);
	let suggestions = $state<User[]>([]);
	let received = $state<FriendRequest[]>([]);
	let friends = $state<User[]>([]);
	let loading = $state(false);
	let sentRequestIds = $state(new Set<string>());
	let searchTimeout: ReturnType<typeof setTimeout>;

	onMount(async () => {
		const [suggestRes, receivedRes] = await Promise.all([
			friendsApi.getSuggestions(),
			friendsApi.getReceived()
		]);
		suggestions = suggestRes.data;
		received = receivedRes.data;
	});

	async function loadFriends() {
		if (friends.length > 0) return;
		loading = true;
		try {
			const res = await friendsApi.getFriends();
			friends = res.data;
		} finally {
			loading = false;
		}
	}

	function onTabChange(t: typeof tab) {
		tab = t;
		if (t === 'friends') loadFriends();
	}

	function onSearch() {
		clearTimeout(searchTimeout);
		if (!searchQuery.trim()) { searchResults = []; return; }
		searchTimeout = setTimeout(async () => {
			const res = await friendsApi.searchUsers(searchQuery);
			searchResults = res.data;
		}, 300);
	}

	async function sendRequest(userId: string) {
		await friendsApi.sendRequest(userId);
		suggestions = suggestions.filter(u => u.id !== userId);
		sentRequestIds = new Set([...sentRequestIds, userId]);
	}

	async function acceptRequest(requestId: string, senderId: string) {
		await friendsApi.accept(requestId);
		received = received.filter(r => r.id !== requestId);
	}

	async function declineRequest(requestId: string) {
		await friendsApi.decline(requestId);
		received = received.filter(r => r.id !== requestId);
	}
</script>

<svelte:head><title>People — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-4">People</h2>

<!-- Tabs -->
<div class="flex gap-1 bg-surface-container-low p-1 rounded-xl mb-5">
	{#each [['discover', 'Discover'], ['requests', `Requests${received.length ? ` (${received.length})` : ''}`], ['friends', 'Friends']] as [value, label]}
		<button
			onclick={() => onTabChange(value as typeof tab)}
			class="flex-1 text-sm font-semibold py-2 rounded-lg transition-colors {tab === value ? 'bg-primary text-on-primary' : 'text-on-surface-variant'}"
		>
			{label}
		</button>
	{/each}
</div>

{#if tab === 'discover'}
	<!-- Search -->
	<div class="relative mb-4">
		<span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-xl">search</span>
		<input
			type="text"
			bind:value={searchQuery}
			oninput={onSearch}
			placeholder="Search by name or username…"
			class="w-full bg-surface-container-low pl-10 pr-4 py-3 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary"
		/>
	</div>

	{#if searchQuery.trim()}
		{#if searchResults.length === 0}
			<p class="text-sm text-on-surface-variant text-center py-8">No users found</p>
		{:else}
			<div class="space-y-2">
				{#each searchResults as user}
					<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl">
						<a href="/profile/{user.id}"><Avatar src={user.avatarUrl} size="sm" /></a>
						<div class="flex-1 min-w-0">
							<a href="/profile/{user.id}" class="font-semibold text-sm">{user.displayName ?? user.username}</a>
							<p class="text-xs text-on-surface-variant">@{user.username}</p>
						</div>
						{#if sentRequestIds.has(user.id)}
							<span class="text-xs font-semibold text-on-surface-variant px-3 py-1.5">Pending</span>
						{:else}
							<button
								onclick={() => sendRequest(user.id)}
								class="text-xs font-semibold text-primary px-3 py-1.5 rounded-lg bg-primary/10"
							>Add</button>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	{:else}
		<h3 class="text-sm font-bold text-on-surface-variant uppercase tracking-widest mb-3">Suggestions</h3>
		{#if suggestions.length === 0}
			<p class="text-sm text-on-surface-variant text-center py-8">No suggestions right now</p>
		{:else}
			<div class="space-y-2">
				{#each suggestions as user}
					<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl">
						<a href="/profile/{user.id}"><Avatar src={user.avatarUrl} size="sm" /></a>
						<div class="flex-1 min-w-0">
							<a href="/profile/{user.id}" class="font-semibold text-sm">{user.displayName ?? user.username}</a>
							<p class="text-xs text-on-surface-variant">@{user.username}</p>
						</div>
						<button
							onclick={() => sendRequest(user.id)}
							class="text-xs font-semibold text-primary px-3 py-1.5 rounded-lg bg-primary/10"
						>
							Add
						</button>
					</div>
				{/each}
			</div>
		{/if}
	{/if}

{:else if tab === 'requests'}
	{#if received.length === 0}
		<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
			<span class="material-symbols-outlined text-5xl">person_add</span>
			<p class="font-semibold">No pending requests</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each received as req}
				<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl">
					<a href="/profile/{req.sender.id}"><Avatar src={req.sender.avatarUrl} size="sm" /></a>
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm">{req.sender.displayName ?? req.sender.username}</p>
						<p class="text-xs text-on-surface-variant">@{req.sender.username}</p>
					</div>
					<div class="flex gap-2">
						<button
							onclick={() => acceptRequest(req.id, req.sender.id)}
							class="text-xs font-semibold text-primary px-3 py-1.5 rounded-lg bg-primary/10"
						>
							Accept
						</button>
						<button
							onclick={() => declineRequest(req.id)}
							class="text-xs font-semibold text-on-surface-variant px-3 py-1.5 rounded-lg bg-surface-container"
						>
							Decline
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}

{:else if tab === 'friends'}
	{#if loading}
		<div class="space-y-2">
			{#each Array(5) as _}
				<div class="h-16 bg-surface-container-low rounded-xl animate-pulse"></div>
			{/each}
		</div>
	{:else if friends.length === 0}
		<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
			<span class="material-symbols-outlined text-5xl">group</span>
			<p class="font-semibold">No friends yet</p>
			<p class="text-sm">Discover people in the Discover tab</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each friends as friend}
				<a href="/profile/{friend.id}" class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl">
					<Avatar src={friend.avatarUrl} size="sm" />
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm">{friend.displayName ?? friend.username}</p>
						<p class="text-xs text-on-surface-variant">@{friend.username}</p>
					</div>
					<span class="material-symbols-outlined text-on-surface-variant">chevron_right</span>
				</a>
			{/each}
		</div>
	{/if}
{/if}
