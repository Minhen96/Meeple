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

	let gamesPage = $state<any>({ content: [], number: 0, last: true, totalPages: 1 });
	let minPlayers = $state<number | undefined>();
	let maxPlayers = $state<number | undefined>();
	let minPlaytime = $state<number | undefined>();
	let maxPlaytime = $state<number | undefined>();
	let minComplexity = $state<number | undefined>();
	let maxComplexity = $state<number | undefined>();
	let minRating = $state<number | undefined>();
	let sortOption = $state<string>('');
	let showFilters = $state(false);
	
	let loadingCatalog = $state(false);

	const collection = $derived(data.collection);

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

	async function fetchCatalogPage(pageNumber: number) {
		loadingCatalog = true;
		try {
			gamesPage = await gamesApi.browse({
				q: query.length >= 2 ? query : undefined,
				minPlayers,
				maxPlayers,
				minPlaytime,
				maxPlaytime,
				minComplexity,
				maxComplexity,
				minRating,
				sort: sortOption || undefined,
				page: pageNumber
			});
		} finally {
			loadingCatalog = false;
		}
	}

	function onQueryInput() {
		clearTimeout(searchTimer);
		if (activeTab === 'all') {
			searchTimer = setTimeout(() => fetchCatalogPage(0), 400);
			return;
		}

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

	$effect(() => {
		if (activeTab === 'all' && gamesPage.content.length === 0 && !loadingCatalog) {
			fetchCatalogPage(0);
		}
	});

	function playerRange(ug: UserGame) {
		const { minPlayers, maxPlayers } = ug.game;
		if (minPlayers && maxPlayers) return `${minPlayers}–${maxPlayers}`;
		if (minPlayers) return `${minPlayers}+`;
		return null;
	}

	function playtime(ug: UserGame) {
		const { playTime } = ug.game;
		if (playTime) return `${playTime} min`;
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
				onclick={() => { 
					activeTab = tab.id; 
					query = ''; 
					searchResults = [];
					if (tab.id === 'all') fetchCatalogPage(0);
				}}
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

{#if activeTab === 'all'}
	<div class="flex justify-between items-center mb-4">
		<button onclick={() => showFilters = !showFilters} class="flex items-center gap-1 text-sm font-bold text-on-surface hover:text-primary transition-colors">
			<span class="material-symbols-outlined text-[18px]">tune</span>
			Filters
		</button>

		<div class="flex items-center gap-2">
			<label for="sort" class="text-xs font-bold text-on-surface-variant">Sort</label>
			<select id="sort" bind:value={sortOption} onchange={() => fetchCatalogPage(0)} class="bg-surface-container-low rounded-lg p-1.5 text-sm outline-none border-none text-on-surface">
				<option value="">Default (Rank)</option>
				<option value="bggRating,desc">Highest Rated</option>
				<option value="yearPublished,desc">Newest First</option>
				<option value="playTime,asc">Shortest Time</option>
				<option value="minPlayers,asc">Lowest Players</option>
			</select>
		</div>
	</div>

	{#if showFilters}
		<div class="grid grid-cols-2 gap-x-4 gap-y-3 mb-6 bg-surface-container-lowest p-4 rounded-xl shadow-sm border border-outline-variant/20">
			<!-- Players -->
			<div class="col-span-2 text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">Players</div>
			<div>
				<input type="number" min="1" max="10" placeholder="Min" bind:value={minPlayers} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>
			<div>
				<input type="number" min="1" max="50" placeholder="Max" bind:value={maxPlayers} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>

			<!-- Playtime -->
			<div class="col-span-2 text-[10px] font-bold uppercase tracking-wider text-on-surface-variant mt-1">Playtime (mins)</div>
			<div>
				<input type="number" min="1" placeholder="Min" bind:value={minPlaytime} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>
			<div>
				<input type="number" min="1" placeholder="Max" bind:value={maxPlaytime} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>

			<!-- Complexity -->
			<div class="col-span-2 text-[10px] font-bold uppercase tracking-wider text-on-surface-variant mt-1">Complexity (1-5)</div>
			<div>
				<input type="number" step="0.1" min="1" max="5" placeholder="Min" bind:value={minComplexity} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>
			<div>
				<input type="number" step="0.1" min="1" max="5" placeholder="Max" bind:value={maxComplexity} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>

			<!-- Rating -->
			<div class="col-span-2 text-[10px] font-bold uppercase tracking-wider text-on-surface-variant mt-1">Rating (1-10)</div>
			<div class="col-span-2">
				<input type="number" step="0.1" min="1" max="10" placeholder="Min Rating" bind:value={minRating} oninput={() => fetchCatalogPage(0)} class="w-full bg-surface-container-low rounded-lg p-2 text-sm focus:outline-none text-on-surface placeholder:text-on-surface-variant" />
			</div>
		</div>
	{/if}
{/if}

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

<!-- 'All Games' Catalog Grid -->
{:else if activeTab === 'all'}
	{#if loadingCatalog && gamesPage.content.length === 0}
		<div class="grid grid-cols-2 gap-4 mt-4">
			{#each { length: 6 } as _}
				<Skeleton class="aspect-[3/4] rounded-xl" />
			{/each}
		</div>
	{:else if gamesPage.content.length === 0}
		<div class="text-center py-12 text-on-surface-variant">
			<span class="material-symbols-outlined text-5xl opacity-40 mb-3 block">search_off</span>
			<p class="font-bold">No games found</p>
			<p class="text-xs mt-1">Try adjusting your filters.</p>
		</div>
	{:else}
		<div class="grid grid-cols-2 gap-4 mt-4">
			{#each gamesPage.content as game}
				<a href="/library/{game.id}" class="group space-y-2">
					<div class="relative aspect-[3/4] rounded-xl overflow-hidden bg-surface-container-high shadow-sm group-hover:shadow-md transition-shadow">
						{#if game.thumbnailUrl}
							<img src={game.thumbnailUrl} alt={game.title} class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" loading="lazy" />
						{:else}
							<div class="w-full h-full flex items-center justify-center">
								<span class="material-symbols-outlined text-4xl text-on-surface-variant opacity-40">casino</span>
							</div>
						{/if}
						{#if game.bggRating}
							<div class="absolute top-2 right-2 bg-surface-container-lowest/90 backdrop-blur px-2 py-0.5 rounded-full flex items-center gap-0.5 shadow-sm">
								<span class="material-symbols-outlined text-primary text-[11px]" style="font-variation-settings: 'FILL' 1;">star</span>
								<span class="text-[10px] font-bold">{game.bggRating.toFixed(1)}</span>
							</div>
						{/if}
						{#if game.rank}
							<div class="absolute top-2 left-2 bg-primary text-on-primary px-2 py-0.5 rounded-full flex items-center shadow-sm">
								<span class="text-[10px] font-extrabold">#{game.rank}</span>
							</div>
						{/if}
					</div>
					<div>
						<p class="text-sm font-bold text-on-surface line-clamp-1 group-hover:text-primary transition-colors">{game.title}</p>
						<div class="flex items-center gap-2 mt-1 text-[11px] text-on-surface-variant font-medium">
							{#if game.minPlayers && game.maxPlayers}
								<span class="flex items-center gap-0.5"><span class="material-symbols-outlined text-[12px]">group</span> {game.minPlayers}-{game.maxPlayers}</span>
							{:else if game.minPlayers}
								<span class="flex items-center gap-0.5"><span class="material-symbols-outlined text-[12px]">group</span> {game.minPlayers}+</span>
							{/if}
							{#if game.playTime}
								<span class="flex items-center gap-0.5"><span class="material-symbols-outlined text-[12px]">timer</span> {game.playTime}m</span>
							{/if}
						</div>
					</div>
				</a>
			{/each}
		</div>

		<div class="flex justify-between items-center mt-6 mb-8">
			<button disabled={gamesPage.number === 0 || loadingCatalog} onclick={() => fetchCatalogPage(gamesPage.number - 1)} class="px-3 py-1.5 bg-surface-container-low text-xs font-bold rounded-lg disabled:opacity-50 text-on-surface">Prev</button>
			<span class="text-[11px] font-bold text-on-surface-variant uppercase tracking-wide">Pg {gamesPage.number + 1} / {gamesPage.totalPages}</span>
			<button disabled={gamesPage.last || loadingCatalog} onclick={() => fetchCatalogPage(gamesPage.number + 1)} class="px-3 py-1.5 bg-surface-container-low text-xs font-bold rounded-lg disabled:opacity-50 text-on-surface">Next</button>
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
