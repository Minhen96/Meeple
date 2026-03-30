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

	const filtered = $derived.by(() => {
		if (query.length >= 2) return [];
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

	function playerRange(ug: UserGame) {
		const { minPlayers, maxPlayers } = ug.game;
		if (minPlayers && maxPlayers) return `${minPlayers}–${maxPlayers}`;
		if (minPlayers) return `${minPlayers}+`;
		return null;
	}

	function playtime(ug: UserGame) {
		const { minPlaytime, maxPlaytime } = ug.game;
		if (minPlaytime && maxPlaytime && minPlaytime !== maxPlaytime) return `${minPlaytime}–${maxPlaytime} min`;
		if (maxPlaytime) return `${maxPlaytime} min`;
		return null;
	}

	const tabs = [
		{ id: 'all',       label: 'All Games' },
		{ id: 'owned',     label: 'My Collection' },
		{ id: 'wishlist',  label: 'Wishlist' },
		{ id: 'favorites', label: 'Favorites' }
	] as const;
</script>

<svelte:head><title>Library — Meeple & Hearth</title></svelte:head>

<!-- Sticky tab bar with underline indicator -->
<div class="sticky top-24 z-40 bg-background -mx-4 px-4 pb-0">
	<div class="flex items-center gap-6 overflow-x-auto hide-scrollbar border-b border-outline-variant/20">
		{#each tabs as tab}
			<button
				onclick={() => { activeTab = tab.id; query = ''; searchResults = []; }}
				class="relative py-3 whitespace-nowrap font-headline font-bold text-sm transition-colors {activeTab === tab.id ? 'text-primary' : 'text-on-surface-variant hover:text-on-surface'}"
			>
				{tab.label}
				{#if activeTab === tab.id}
					<div class="absolute bottom-0 left-0 w-full h-0.5 bg-primary rounded-t-full"></div>
				{/if}
			</button>
		{/each}
	</div>
</div>

<!-- Search bar -->
<div class="mt-4 mb-2">
	<div class="flex items-center gap-3 bg-surface-container-lowest rounded-xl px-4 py-3 shadow-[0_8px_24px_rgba(0,0,0,0.04)]">
		<span class="material-symbols-outlined text-on-surface-variant text-[20px]">search</span>
		<input
			type="search"
			placeholder="Search games..."
			bind:value={query}
			oninput={onQueryInput}
			class="flex-1 bg-transparent text-on-surface placeholder:text-on-surface-variant focus:outline-none font-body text-sm"
		/>
		{#if query}
			<button onclick={() => { query = ''; searchResults = []; }} class="text-on-surface-variant">
				<span class="material-symbols-outlined text-[18px]">close</span>
			</button>
		{/if}
	</div>
</div>

<!-- BGG search results -->
{#if showSearch}
	{#if searching}
		<div class="space-y-3 mt-4">
			{#each { length: 4 } as _}
				<div class="flex gap-3 items-center">
					<Skeleton class="w-12 h-16 rounded-lg" />
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
					class="flex items-center gap-3 bg-surface-container-lowest rounded-xl p-3 shadow-sm spring-bounce"
				>
					{#if result.thumbnailUrl}
						<img src={result.thumbnailUrl} alt={result.title} class="w-12 h-16 object-cover rounded-lg flex-shrink-0" />
					{:else}
						<div class="w-12 h-16 bg-surface-container-high rounded-lg flex items-center justify-center flex-shrink-0">
							<span class="material-symbols-outlined text-on-surface-variant">casino</span>
						</div>
					{/if}
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm text-on-surface line-clamp-1">{result.title}</p>
						{#if result.yearPublished}
							<p class="text-xs text-on-surface-variant mt-0.5">{result.yearPublished}</p>
						{/if}
					</div>
					<span class="material-symbols-outlined text-on-surface-variant text-[20px]">chevron_right</span>
				</a>
			{/each}
		</div>
	{/if}

<!-- Collection grid -->
{:else if filtered.length === 0}
	<div class="text-center py-16 text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl mb-3 block opacity-40">library_books</span>
		<p class="font-semibold">No games here</p>
		<p class="text-sm mt-1">Search above to find and add games.</p>
	</div>
{:else}
	<div class="grid grid-cols-2 gap-4 mt-4">
		{#each filtered as ug (ug.id)}
			<a href="/library/{ug.game.id}" class="group space-y-2">
				<!-- Card with overlay badges -->
				<div class="relative aspect-[3/4] rounded-xl overflow-hidden bg-surface-container-high shadow-[0_12px_32px_rgba(0,0,0,0.06)] group-hover:shadow-xl group-hover:-translate-y-1 transition-all duration-300">
					{#if ug.game.thumbnailUrl}
						<img
							src={ug.game.thumbnailUrl}
							alt={ug.game.title}
							class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
							loading="lazy"
						/>
					{:else}
						<div class="w-full h-full flex items-center justify-center">
							<span class="material-symbols-outlined text-4xl text-on-surface-variant opacity-40">casino</span>
						</div>
					{/if}

					<!-- Rating badge top-right -->
					{#if ug.game.bggRating}
						<div class="absolute top-2 right-2 bg-surface-container-lowest/90 backdrop-blur px-2 py-0.5 rounded-full flex items-center gap-0.5">
							<span class="material-symbols-outlined text-primary-container text-[13px]" style="font-variation-settings: 'FILL' 1;">star</span>
							<span class="text-[11px] font-label font-bold">{ug.game.bggRating.toFixed(1)}</span>
						</div>
					{/if}

					<!-- Owned badge top-left -->
					{#if ug.isOwned}
						<div class="absolute top-2 left-2 bg-tertiary text-on-tertiary px-2 py-0.5 rounded-full text-[10px] font-label font-bold">
							Owned
						</div>
					{/if}
				</div>

				<!-- Title + meta -->
				<div>
					<p class="text-sm font-bold text-on-surface line-clamp-2 leading-tight group-hover:text-primary transition-colors">
						{ug.game.title}
					</p>
					<div class="flex items-center gap-3 mt-1 text-[11px] text-on-surface-variant font-label">
						{#if playerRange(ug)}
							<span class="flex items-center gap-0.5">
								<span class="material-symbols-outlined text-[13px]">group</span>
								{playerRange(ug)}
							</span>
						{/if}
						{#if playtime(ug)}
							<span class="flex items-center gap-0.5">
								<span class="material-symbols-outlined text-[13px]">timer</span>
								{playtime(ug)}
							</span>
						{/if}
					</div>
				</div>
			</a>
		{/each}
	</div>
{/if}
