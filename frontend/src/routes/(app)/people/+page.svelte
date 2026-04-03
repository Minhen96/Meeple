<script lang="ts">
	import { onMount } from 'svelte';
	import { friendsApi } from '$lib/api/friends';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { peopleSearchHistory } from '$lib/stores/peopleSearch';
	import type { User } from '$lib/types';

	let searchQuery = $state('');
	let searchResults = $state<User[]>([]);
	let suggestions = $state<User[]>([]);
	let loading = $state(false);
	let searchTimeout: ReturnType<typeof setTimeout>;

	onMount(async () => {
		const suggestRes = await friendsApi.getSuggestions();
		suggestions = suggestRes?.data ?? [];
	});

	function onSearch() {
		clearTimeout(searchTimeout);
		if (!searchQuery.trim()) {
			searchResults = [];
			return;
		}
		loading = true;
		searchTimeout = setTimeout(async () => {
			try {
				const res = await friendsApi.searchUsers(searchQuery);
				searchResults = res?.data ?? [];
			} finally {
				loading = false;
			}
		}, 300);
	}

	function handleUserClick(user: User) {
		peopleSearchHistory.add(user);
	}
</script>

<svelte:head><title>Search — Meeple</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-4">Search</h2>

<!-- Search Input -->
<div class="relative mb-6">
	<span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-xl">
		search
	</span>
	<input
		type="text"
		bind:value={searchQuery}
		oninput={onSearch}
		placeholder="Search for people…"
		class="w-full bg-surface-container-low pl-10 pr-4 py-3.5 rounded-2xl text-sm outline-none focus:ring-2 focus:ring-primary transition-all shadow-sm"
		autofocus
	/>
</div>

{#if searchQuery.trim()}
	{#if loading && searchResults.length === 0}
		<div class="space-y-4">
			{#each Array(3) as _}
				<div class="h-16 bg-surface-container-low rounded-xl animate-pulse"></div>
			{/each}
		</div>
	{:else if searchResults.length === 0}
		<div class="text-center py-12">
			<span class="material-symbols-outlined text-4xl text-on-surface-variant mb-2">person_off</span>
			<p class="text-sm text-on-surface-variant">No users found for "{searchQuery}"</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each searchResults as user}
				<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl hover:bg-surface-container transition-colors">
					<a href="/profile/{user.id}" onclick={() => handleUserClick(user)}>
						<Avatar src={user.avatarUrl} size="sm" />
					</a>
					<div class="flex-1 min-w-0">
						<a href="/profile/{user.id}" onclick={() => handleUserClick(user)} class="font-semibold text-sm">
							{user.displayName ?? user.username}
						</a>
						<p class="text-xs text-on-surface-variant">@{user.username}</p>
					</div>
					<a
						href="/profile/{user.id}"
						onclick={() => handleUserClick(user)}
						class="material-symbols-outlined text-on-surface-variant"
					>
						chevron_right
					</a>
				</div>
			{/each}
		</div>
	{/if}
{:else}
	<!-- History -->
	{#if $peopleSearchHistory.length > 0}
		<div class="mb-8">
			<div class="flex justify-between items-center mb-3 px-1">
				<h3 class="text-xs font-bold text-on-surface-variant uppercase tracking-widest">Recent</h3>
				<button 
					onclick={() => peopleSearchHistory.clear()}
					class="text-xs font-semibold text-primary hover:underline"
				>
					Clear All
				</button>
			</div>
			<div class="flex gap-4 overflow-x-auto pb-4 -mx-1 px-1 scrollbar-hide">
				{#each $peopleSearchHistory as user}
					<div class="flex flex-col items-center gap-1.5 min-w-[72px] relative group">
						<button 
							onclick={() => peopleSearchHistory.remove(user.id)}
							class="absolute -top-1 -right-1 bg-surface-container rounded-full p-0.5 text-on-surface-variant opacity-0 group-hover:opacity-100 transition-opacity z-10"
							aria-label="Remove from history"
						>
							<span class="material-symbols-outlined text-[14px]">close</span>
						</button>
						<a href="/profile/{user.id}" onclick={() => handleUserClick(user)} class="flex flex-col items-center gap-1.5">
							<Avatar src={user.avatarUrl} size="md" />
							<span class="text-[10px] font-semibold text-center line-clamp-1 w-full max-w-[64px]">
								{user.displayName ?? user.username}
							</span>
						</a>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Suggestions -->
	<h3 class="text-xs font-bold text-on-surface-variant uppercase tracking-widest mb-3 px-1">
		Suggested
	</h3>
	{#if suggestions.length === 0}
		<div class="space-y-2">
			{#each Array(3) as _}
				<div class="h-16 bg-surface-container-low rounded-xl animate-pulse"></div>
			{/each}
		</div>
	{:else}
		<div class="space-y-2">
			{#each suggestions as user}
				<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl hover:bg-surface-container transition-colors">
					<a href="/profile/{user.id}" onclick={() => handleUserClick(user)}><Avatar src={user.avatarUrl} size="sm" /></a>
					<div class="flex-1 min-w-0">
						<a href="/profile/{user.id}" onclick={() => handleUserClick(user)} class="font-semibold text-sm">
							{user.displayName ?? user.username}
						</a>
						<p class="text-xs text-on-surface-variant">@{user.username}</p>
					</div>
					<a
						href="/profile/{user.id}"
						onclick={() => handleUserClick(user)}
						class="text-xs font-semibold text-primary px-4 py-1.5 rounded-full bg-primary/10 hover:bg-primary/20 transition-colors"
					>
						View
					</a>
				</div>
			{/each}
		</div>
	{/if}
{/if}

<style>
	.scrollbar-hide::-webkit-scrollbar {
		display: none;
	}
	.scrollbar-hide {
		-ms-overflow-style: none;
		scrollbar-width: none;
	}
</style>
