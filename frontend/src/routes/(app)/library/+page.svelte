<script lang="ts">
	import type { PageData } from './$types';
	import type { GameSearchResult, UserGame } from '$lib/types';
	import { gamesApi } from '$lib/api/games';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	let activeTab = $state<'all' | 'owned' | 'wishlist' | 'favorites'>('all');
	let query = $state('');
	let searchResults = $state<GameSearchResult[]>([]);
	let searching = $state(false);
	let searchTimer: ReturnType<typeof setTimeout>;

	const collection: UserGame[] = data.collection;

	const filtered = $derived(() => {
		if (query.length >= 2) return []; // show search results instead
		switch (activeTab) {
			case 'owned':     return collection.filter((g) => g.isOwned);
			case 'wishlist':  return collection.filter((g) => g.isWishlisted);
			case 'favorites': return collection.filter((g) => g.isFavorited);
			default:          return collection;
		}
	});

	const showSearch = $derived(query.length >= 2);

	function onQueryInput() {
		clearTimeout(searchTimer);
		searchResults = [];
		if (query.length < 2) { searching = false; return; }
		searching = true;
		searchTimer = setTimeout(async () => {
			try {
				searchResults = await gamesApi.search(query);
			} finally {
				searching = false;
			}
		}, 400);
	}

	const tabs = [
		{ id: 'all',       label: 'All' },
		{ id: 'owned',     label: 'Owned' },
		{ id: 'wishlist',  label: 'Wishlist' },
		{ id: 'favorites', label: 'Favorites' }
	] as const;
</script>

<svelte:head><title>Library — Meeple & Hearth</title></svelte:head>

<!-- Search bar -->
<div class="sticky top-24 z-40 bg-background pb-2">
	<input
		type="search"
		placeholder="Search games..."
		bind:value={query}
		oninput={onQueryInput}
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	{#if !showSearch}
		<div class="flex gap-2 mt-3 overflow-x-auto hide-scrollbar">
			{#each tabs as tab}
				<button
					onclick={() => (activeTab = tab.id)}
					class="flex-shrink-0 px-4 py-2 rounded-full text-sm font-label font-bold transition-colors {activeTab === tab.id ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
				>{tab.label}</button>
			{/each}
		</div>
	{/if}
</div>

<!-- BGG search results -->
{#if showSearch}
	{#if searching}
		<div class="space-y-3 mt-4">
			{#each { length: 4 } as _}
				<div class="flex gap-3 items-center">
					<Skeleton class="w-12 h-16" />
					<div class="space-y-2 flex-1">
						<Skeleton class="h-3 w-3/4" />
						<Skeleton class="h-2 w-1/3" />
					</div>
				</div>
			{/each}
		</div>
	{:else if searchResults.length === 0}
		<p class="text-center text-on-surface-variant text-sm py-12">No games found for "{query}"</p>
	{:else}
		<div class="space-y-2 mt-4">
			{#each searchResults as result (result.bggId)}
				<a
					href={result.id ? `/library/${result.id}` : '#'}
					class="flex items-center gap-3 bg-surface-container-lowest rounded-xl p-3"
				>
					{#if result.thumbnailUrl}
						<img src={result.thumbnailUrl} alt={result.title} class="w-12 h-16 object-cover rounded-lg" />
					{:else}
						<div class="w-12 h-16 bg-surface-container-high rounded-lg flex items-center justify-center">
							<span class="material-symbols-outlined text-on-surface-variant">casino</span>
						</div>
					{/if}
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm text-on-surface line-clamp-1">{result.title}</p>
						{#if result.yearPublished}
							<p class="text-xs text-on-surface-variant">{result.yearPublished}</p>
						{/if}
					</div>
					<span class="material-symbols-outlined text-on-surface-variant">chevron_right</span>
				</a>
			{/each}
		</div>
	{/if}

<!-- Collection grid -->
{:else if filtered().length === 0}
	<div class="text-center py-16 text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl mb-3 block opacity-40">library_books</span>
		<p class="font-semibold">No games here</p>
		<p class="text-sm mt-1">Search above to find and add games.</p>
	</div>
{:else}
	<div class="grid grid-cols-3 gap-3 mt-4">
		{#each filtered() as ug (ug.id)}
			<a href="/library/{ug.game.id}" class="space-y-1.5">
				{#if ug.game.thumbnailUrl}
					<img
						src={ug.game.thumbnailUrl}
						alt={ug.game.title}
						class="w-full aspect-[3/4] object-cover rounded-xl"
						loading="lazy"
					/>
				{:else}
					<div class="w-full aspect-[3/4] bg-surface-container-high rounded-xl flex items-center justify-center">
						<span class="material-symbols-outlined text-2xl text-on-surface-variant">casino</span>
					</div>
				{/if}
				<p class="text-xs font-semibold text-on-surface line-clamp-2 leading-tight">{ug.game.title}</p>
				{#if ug.game.yearPublished}
					<p class="text-[10px] text-on-surface-variant">{ug.game.yearPublished}</p>
				{/if}
			</a>
		{/each}
	</div>
{/if}
