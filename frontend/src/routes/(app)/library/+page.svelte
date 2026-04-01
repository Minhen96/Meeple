<script lang="ts">
	import type { PageData } from "./$types";
	import type { GameSearchResult, UserGame } from "$lib/types";
	import { gamesApi } from "$lib/api/games";
	import { libraryStore } from "$lib/stores/library";
	import Skeleton from "$lib/components/ui/Skeleton.svelte";
	import { goto } from "$app/navigation";
	import { toast } from "svelte-sonner";

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	// Persisted across navigations via store
	let store = $state($libraryStore);
	$effect(() => {
		libraryStore.set(store);
	});

	let activeTab = $derived(store.activeTab);
	let gamesPage = $derived(store.gamesPage);
	let minPlayers = $derived(store.minPlayers);
	let maxPlayers = $derived(store.maxPlayers);
	let minPlaytime = $derived(store.minPlaytime);
	let maxPlaytime = $derived(store.maxPlaytime);
	let minComplexity = $derived(store.minComplexity);
	let maxComplexity = $derived(store.maxComplexity);
	let minRating = $derived(store.minRating);
	let sortOption = $derived(store.sortOption);
	let selectedGenre = $derived(store.selectedGenre);

	let query = $state("");
	let searchResults = $state<GameSearchResult[]>([]);
	let searching = $state(false);

	let showFilters = $state(false);
	let loadingCatalog = $state(false);

	const collection = $derived(data.collection);

	const filtered = $derived.by(() => {
		let items: UserGame[];
		switch (activeTab) {
			case "owned":
				items = collection.filter((g) => g.isOwned);
				break;
			case "played":
				items = [...collection.filter((g) => g.playCount > 0)].sort(
					(a, b) => b.playCount - a.playCount,
				);
				break;
			case "favorites":
				items = collection.filter((g) => g.isFavorited);
				break;
			default:
				items = collection;
				break;
		}
		if (query.length >= 2 && activeTab !== "all") {
			const q = query.toLowerCase();
			items = items.filter((ug) => ug.game.title?.toLowerCase().includes(q));
		}
		return items;
	});

	// Only show the search-results panel for collection tabs (all-tab uses gamesPage directly)
	const showSearch = $derived(query.length >= 2 && activeTab !== "all");

	let loadingMore = $state(false);
	let observerNode = $state<HTMLElement | null>(null);

	async function fetchCatalogPage(pageNumber: number, append = false) {
		if (loadingCatalog || loadingMore) return;

		if (append) loadingMore = true;
		else loadingCatalog = true;

		try {
			const result = await gamesApi.browse({
				q: query || undefined,
				genre: store.selectedGenre || undefined,
				minPlayers: store.minPlayers,
				maxPlayers: store.maxPlayers,
				minPlaytime: store.minPlaytime,
				maxPlaytime: store.maxPlaytime,
				minComplexity: store.minComplexity,
				maxComplexity: store.maxComplexity,
				minRating: store.minRating,
				sort: store.sortOption || undefined,
				page: pageNumber,
			});

			if (append) {
				store = {
					...store,
					gamesPage: {
						...result,
						content: [
							...store.gamesPage.content,
							...result.content,
						],
					},
				};
			} else {
				store = { ...store, gamesPage: result };
			}
		} finally {
			loadingCatalog = false;
			loadingMore = false;
		}
	}

	let searchTimer: ReturnType<typeof setTimeout>;
	function onQueryInput() {
		clearTimeout(searchTimer);
		if (activeTab === "all") {
			searchTimer = setTimeout(() => fetchCatalogPage(0), 400);
			return;
		}
	}

	// Initial load
	$effect(() => {
		if (
			activeTab === "all" &&
			gamesPage.number === 0 &&
			gamesPage.totalElements === 0 &&
			!loadingCatalog
		) {
			fetchCatalogPage(0);
		}
	});

	// Infinite scroll observer
	$effect(() => {
		if (!observerNode || activeTab !== "all" || gamesPage.last) return;

		const observer = new IntersectionObserver(
			(entries) => {
				if (
					entries[0].isIntersecting &&
					!loadingMore &&
					!loadingCatalog
				) {
					fetchCatalogPage(gamesPage.number + 1, true);
				}
			},
			{ rootMargin: "400px" },
		);

		observer.observe(observerNode);
		return () => observer.disconnect();
	});

	const activeFilterCount = $derived.by(() => {
		let count = 0;
		if (store.selectedGenre) count++;
		if (store.minPlayers || store.maxPlayers) count++;
		if (store.minPlaytime || store.maxPlaytime) count++;
		if (store.minComplexity || store.maxComplexity) count++;
		if (store.minRating) count++;
		return count;
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
		{ id: "all", label: "All Games" },
		{ id: "favorites", label: "Favorites" },
		{ id: "owned", label: "Collection" },
		{ id: "played", label: "Played" },
	] as const;

	// Spotlight data (hardcoded for now as per design)
	const spotlight = {
		title: "Gloomhaven",
		description:
			"Embark on an epic legacy campaign with over 95 scenarios of tactical combat and character progression.",
		category: "Game of the Week",
		imageUrl:
			"https://lh3.googleusercontent.com/aida-public/AB6AXuD9OrJ1s0wkQqNwd_2YHUbBl6iHCyN8nOBpB4M5CCRPcCrAdiFtFi6vdGS7g51uWG11sEi2A5xZ224aDw5sUYAf5hAOBolULCapAp1U2NWzEUAn_m7t1eK_1q4g-mM8sv8KTArVqCvmLHfz1szDbFToCottMw8Y9l99X7PAbtnF4V5WjZEeNd784ek1C-GJ2U_pw2-CzblT4s91OMRI2OG9cn0CVbWT5_Dsc7UUa3uasDGIn6zx5pkZN2v-oEsMxd98qQvrdP7Nqw0",
	};

	const categories = ["Strategy", "Party", "Family", "2 Player", "Abstract"];

	let spotlightSaving = $state(false);

	async function exploreSpotlight() {
		const results = await gamesApi.search(spotlight.title).catch(() => []);
		const hit = results.find((r) => r.id);
		if (hit?.id) goto(`/library/${hit.id}`);
	}

	async function saveSpotlight() {
		const results = await gamesApi.search(spotlight.title).catch(() => []);
		const hit = results.find((r) => r.id);
		if (!hit?.id) return;
		spotlightSaving = true;
		try {
			await gamesApi.updateCollection(hit.id, { isFavorited: true });
			toast.success(`${spotlight.title} added to favorites!`);
		} catch {
			toast.error('Could not save');
		} finally {
			spotlightSaving = false;
		}
	}
</script>

<svelte:head><title>Library — Meeple & Hearth</title></svelte:head>

<!-- Sticky Unified Header -->
<div
	class="sticky top-14 z-40 bg-background/95 backdrop-blur -mx-4 px-4 pb-3 border-b border-outline-variant/10 shadow-sm"
>
	<!-- Tab Bar -->
	<div
		class="flex items-center gap-6 overflow-x-auto hide-scrollbar border-b border-outline-variant/5 mb-3"
	>
		{#each tabs as tab}
			<button
				onclick={() => {
					store = { ...store, activeTab: tab.id };
					query = "";
					searchResults = [];
					if (tab.id === "all") fetchCatalogPage(0);
				}}
				class="relative py-4 whitespace-nowrap font-headline font-bold text-sm transition-colors {activeTab ===
				tab.id
					? 'text-primary'
					: 'text-on-surface-variant hover:text-on-surface'}"
			>
				{tab.label}
				{#if activeTab === tab.id}
					<div
						class="absolute bottom-0 left-0 w-full h-1 bg-primary rounded-t-full"
					></div>
				{/if}
			</button>
		{/each}
	</div>

	<!-- Discovery Ribbon -->
	<div class="flex items-center gap-3">
		<!-- Search (Expands) -->
		<div
			class="flex-1 flex items-center gap-2 bg-surface-container-low rounded-2xl px-4 py-2 border border-outline-variant/5 focus-within:border-primary/20 transition-all shadow-inner"
		>
			<span
				class="material-symbols-outlined text-[20px] text-on-surface-variant"
				>search</span
			>
			<input
				type="search"
				placeholder="Search catalog..."
				bind:value={query}
				oninput={onQueryInput}
				class="flex-1 bg-transparent text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none py-1"
			/>
		</div>

		<!-- Filter Button -->
		<button
			onclick={() => (showFilters = !showFilters)}
			class="relative w-11 h-11 flex items-center justify-center rounded-2xl bg-surface-container-high border border-outline-variant/5 text-primary hover:bg-surface-variant transition-colors"
		>
			<span class="material-symbols-outlined">tune</span>
			{#if activeFilterCount > 0}
				<span
					class="absolute -top-1 -right-1 w-5 h-5 bg-primary text-on-primary text-[10px] font-black rounded-full flex items-center justify-center border-2 border-background animate-in zoom-in"
				>
					{activeFilterCount}
				</span>
			{/if}
		</button>

		<!-- Sort Select (Compact) -->
		<div class="relative group">
			<select
				value={sortOption}
				onchange={(e) => {
					store = {
						...store,
						sortOption: (e.target as HTMLSelectElement).value,
					};
					fetchCatalogPage(0);
				}}
				class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
			>
				<option value="">Sort</option>
				<option value="recommended">Recommended ✨</option>
				<option value="rank,asc">Rank</option>
				<option value="bggRating,desc">Rating</option>
				<option value="yearPublished,desc">Newest</option>
				<option value="playTime,asc">Shortest</option>
			</select>
			<div
				class="w-11 h-11 flex items-center justify-center rounded-2xl bg-surface-container-high border border-outline-variant/5 text-primary"
			>
				<span class="material-symbols-outlined">sort</span>
			</div>
		</div>
	</div>
</div>

<div class="mt-4 mb-6">
	{#if activeTab === "all" && !query}
		<!-- Compact Hero Section -->
		<section
			class="mb-8 animate-in fade-in slide-in-from-bottom-4 duration-700"
		>
			<div
				class="relative h-[240px] rounded-[2rem] overflow-hidden group shadow-xl shadow-primary/5"
			>
				<img
					src={spotlight.imageUrl}
					alt={spotlight.title}
					class="absolute inset-0 w-full h-full object-cover transition-transform duration-1000 group-hover:scale-105"
				/>
				<div
					class="absolute inset-0 bg-gradient-to-t from-black/90 via-black/30 to-transparent"
				></div>
				<div class="absolute bottom-0 left-0 p-6 w-full">
					<div class="flex justify-between items-end gap-4">
						<div class="flex-1">
							<span
								class="inline-block px-3 py-0.5 rounded-full bg-primary text-on-primary font-bold text-[9px] uppercase tracking-widest mb-2"
							>
								{spotlight.category}
							</span>
							<h3
								class="text-white font-headline text-2xl font-extrabold mb-1"
							>
								{spotlight.title}
							</h3>
							<p
								class="text-white/70 max-w-md font-body text-xs line-clamp-2"
							>
								{spotlight.description}
							</p>
						</div>
						<div class="flex items-center gap-2 shrink-0">
							<button
								onclick={exploreSpotlight}
								class="bg-white text-on-background px-5 py-2 rounded-full font-bold text-xs hover:bg-primary hover:text-white transition-all active:scale-95 shadow-lg"
							>
								Explore
							</button>
							<button
								onclick={saveSpotlight}
								disabled={spotlightSaving}
								class="w-9 h-9 rounded-full bg-white/10 backdrop-blur-md border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all disabled:opacity-50"
							>
								<span class="material-symbols-outlined text-[20px]">bookmark</span>
							</button>
						</div>
					</div>
				</div>
			</div>
		</section>
	{/if}
</div>

{#if showFilters && activeTab === "all"}
	<div
		class="fixed inset-0 z-[100] flex items-end sm:items-center justify-center p-4"
	>
		<!-- Backdrop -->
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="absolute inset-0 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300"
			onclick={() => (showFilters = false)}
		></div>

		<!-- Modal Content -->
		<div
			class="relative w-full max-w-lg bg-surface-container-lowest rounded-[2.5rem] shadow-2xl border border-outline-variant/10 overflow-hidden animate-in slide-in-from-bottom-10 duration-500"
		>
			<div class="p-8">
				<div class="flex items-center justify-between mb-8">
					<h2
						class="font-headline text-2xl font-extrabold text-on-surface"
					>
						Discovery Filters
					</h2>
					<button
						onclick={() => (showFilters = false)}
						class="w-10 h-10 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface-variant hover:text-on-surface transition-colors"
					>
						<span class="material-symbols-outlined">close</span>
					</button>
				</div>

				<div
					class="space-y-8 max-h-[60vh] overflow-y-auto pr-2 hide-scrollbar"
				>
					<!-- Genre -->
					<div class="space-y-3">
						<span class="text-xs font-black uppercase tracking-widest text-on-surface-variant">Genre</span>
						<div class="flex flex-wrap gap-2">
							{#each ['Strategy', 'Party', 'Family', '2 Player', 'Abstract'] as cat}
								<button
									onclick={() => {
										store = { ...store, selectedGenre: selectedGenre === cat ? '' : cat };
										fetchCatalogPage(0);
									}}
									class="px-4 py-2 rounded-2xl text-sm font-bold transition-all {selectedGenre === cat ? 'bg-primary text-on-primary' : 'bg-surface-container-low text-on-surface-variant'}"
								>
									{cat}
								</button>
							{/each}
						</div>
					</div>

					<!-- Player Count -->
					<div class="space-y-4">
						<div class="flex items-center justify-between">
							<span
								class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
								>Player Dynamics</span
							>
							<span class="text-[10px] font-bold text-primary"
								>Min - Max</span
							>
						</div>
						<div class="grid grid-cols-2 gap-4">
							<input
								type="number"
								min="1"
								max="10"
								placeholder="Min"
								value={minPlayers}
								oninput={(e) => {
									store = {
										...store,
										minPlayers:
											+(e.target as HTMLInputElement)
												.value || undefined,
									};
									fetchCatalogPage(0);
								}}
								class="bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
							/>
							<input
								type="number"
								min="1"
								max="50"
								placeholder="Max"
								value={maxPlayers}
								oninput={(e) => {
									store = {
										...store,
										maxPlayers:
											+(e.target as HTMLInputElement)
												.value || undefined,
									};
									fetchCatalogPage(0);
								}}
								class="bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
							/>
						</div>
					</div>

					<!-- Playtime -->
					<div class="space-y-4">
						<div class="flex items-center justify-between">
							<span
								class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
								>Playtime (Mins)</span
							>
						</div>
						<div class="grid grid-cols-2 gap-4">
							<input
								type="number"
								min="1"
								placeholder="Min"
								value={minPlaytime}
								oninput={(e) => {
									store = {
										...store,
										minPlaytime:
											+(e.target as HTMLInputElement)
												.value || undefined,
									};
									fetchCatalogPage(0);
								}}
								class="bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
							/>
							<input
								type="number"
								min="1"
								placeholder="Max"
								value={maxPlaytime}
								oninput={(e) => {
									store = {
										...store,
										maxPlaytime:
											+(e.target as HTMLInputElement)
												.value || undefined,
									};
									fetchCatalogPage(0);
								}}
								class="bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
							/>
						</div>
					</div>

					<!-- Complexity & Rating -->
					<div class="grid grid-cols-2 gap-8">
						<div class="space-y-4">
							<span
								class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
								>Min Rating</span
							>
							<input
								type="number"
								step="0.1"
								min="0"
								max="10"
								placeholder="0.0"
								value={minRating}
								oninput={(e) => {
									store = {
										...store,
										minRating:
											+(e.target as HTMLInputElement)
												.value || undefined,
									};
									fetchCatalogPage(0);
								}}
								class="w-full bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
							/>
						</div>
						<div class="space-y-4">
							<span
								class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
								>Complexity</span
							>
							<div class="flex gap-2">
								<input
									type="number"
									step="0.1"
									min="1"
									max="5"
									placeholder="Min"
									value={store.minComplexity}
									oninput={(e) => {
										store = {
											...store,
											minComplexity:
												+(e.target as HTMLInputElement)
													.value || undefined,
										};
										fetchCatalogPage(0);
									}}
									class="w-full bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
								/>
								<input
									type="number"
									step="0.1"
									min="1"
									max="5"
									placeholder="Max"
									value={store.maxComplexity}
									oninput={(e) => {
										store = {
											...store,
											maxComplexity:
												+(e.target as HTMLInputElement)
													.value || undefined,
										};
										fetchCatalogPage(0);
									}}
									class="w-full bg-surface-container-low rounded-2xl p-4 text-sm focus:outline-none text-on-surface border border-transparent focus:border-primary/20 transition-all"
								/>
							</div>
						</div>
					</div>
				</div>

				<div class="mt-10 flex gap-4">
					<button
						onclick={() => {
							store = {
								...store,
								selectedGenre: '',
								minPlayers: undefined,
								maxPlayers: undefined,
								minPlaytime: undefined,
								maxPlaytime: undefined,
								minComplexity: undefined,
								maxComplexity: undefined,
								minRating: undefined,
							};
							fetchCatalogPage(0);
						}}
						class="flex-1 py-4 rounded-2xl font-bold text-sm text-on-surface-variant hover:bg-surface-container-high transition-colors"
					>
						Reset
					</button>
					<button
						onclick={() => (showFilters = false)}
						class="flex-[2] py-4 rounded-2xl bg-primary text-on-primary font-bold text-sm shadow-lg shadow-primary/20 active:scale-95 transition-all"
					>
						Apply Results
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<!-- BGG search results -->
{#if showSearch}
	{#if searching}
		<div class="space-y-4 mt-6">
			{#each { length: 4 } as _}
				<div
					class="flex gap-4 items-center bg-surface-container-low/50 p-3 rounded-2xl"
				>
					<Skeleton class="w-16 h-20 rounded-xl" />
					<div class="space-y-2 flex-1">
						<Skeleton class="h-4 w-3/4 rounded-md" />
						<Skeleton class="h-3 w-1/3 rounded-md" />
					</div>
				</div>
			{/each}
		</div>
	{:else if searchResults.length === 0}
		<div
			class="text-center py-20 bg-surface-container-lowest rounded-[2rem] border border-outline-variant/10 mt-6"
		>
			<span
				class="material-symbols-outlined text-6xl text-primary/20 mb-4 block"
				>search_off</span
			>
			<p class="text-on-surface font-bold text-lg">No results found</p>
			<p class="text-on-surface-variant text-sm mt-1">
				Try a different title or keyword.
			</p>
		</div>
	{:else}
		{#if searchResults[0]?.translatedFrom}
			<div class="px-1 mb-4 flex items-center gap-2 text-primary animate-in fade-in slide-in-from-left-4">
				<span class="material-symbols-outlined text-[18px]">translate</span>
				<p class="text-xs font-bold uppercase tracking-widest">
					Showing results for: <span class="italic text-on-surface">{searchResults[0].title}</span>
				</p>
			</div>
		{/if}
		<div class="space-y-3 mt-6">
			{#each searchResults as result (result.bggId)}
				<a
					href={result.id ? `/library/${result.id}` : "#"}
					class="flex items-center gap-4 bg-surface-container-lowest rounded-2xl p-3 shadow-sm border border-outline-variant/5 hover:border-primary/20 transition-all spring-bounce group"
				>
					{#if result.thumbnailUrl}
						<img
							src={result.thumbnailUrl}
							alt={result.title}
							class="w-16 h-20 object-cover rounded-xl flex-shrink-0 group-hover:scale-105 transition-transform"
						/>
					{:else}
						<div
							class="w-16 h-20 bg-surface-container-high rounded-xl flex items-center justify-center flex-shrink-0"
						>
							<span
								class="material-symbols-outlined text-on-surface-variant"
								>casino</span
							>
						</div>
					{/if}
					<div class="flex-1 min-w-0">
						<p
							class="font-bold text-on-surface group-hover:text-primary transition-colors truncate"
						>
							{result.title}
						</p>
						{#if result.yearPublished}
							<p
								class="text-xs text-on-surface-variant mt-1 font-label"
							>
								{result.yearPublished}
							</p>
						{/if}
					</div>
					<span
						class="material-symbols-outlined text-on-surface-variant/40 group-hover:text-primary transition-colors"
						>chevron_right</span
					>
				</a>
			{/each}
		</div>
	{/if}

	<!-- 'All Games' Catalog Grid Header (Cleaned Up) -->
{:else if activeTab === "all"}
	<div class="flex items-center justify-between mb-6">
		<div class="flex flex-col">
			<h2 class="font-headline text-xl font-extrabold text-on-surface">
				Library Feed
			</h2>
			<span
				class="text-[10px] font-black text-on-surface-variant uppercase tracking-widest mt-1 opacity-70"
			>
				{gamesPage.totalElements || "0"} Results
			</span>
		</div>
	</div>

	{#if loadingCatalog && gamesPage.content.length === 0}
		<div class="grid grid-cols-2 gap-5">
			{#each { length: 6 } as _}
				<div class="space-y-3">
					<Skeleton class="aspect-[3/4] rounded-[2rem]" />
					<Skeleton class="h-4 w-3/4 rounded-md" />
					<Skeleton class="h-3 w-1/2 rounded-md" />
				</div>
			{/each}
		</div>
	{:else if gamesPage.content.length === 0}
		<div
			class="text-center py-20 bg-surface-container-lowest rounded-[2rem] border border-outline-variant/10"
		>
			<span
				class="material-symbols-outlined text-6xl text-primary/20 mb-4 block"
				>explore_off</span
			>
			{#if store.sortOption === 'recommended'}
				<p class="font-bold text-lg">No recommendations yet</p>
				<p class="text-sm text-on-surface-variant mt-1">
					Favorite or log some plays to get personalized suggestions.
				</p>
			{:else}
				<p class="font-bold text-lg">The library feels empty</p>
				<p class="text-sm text-on-surface-variant mt-1">
					Adjust your filters to see more games.
				</p>
			{/if}
		</div>
	{:else}
		<div class="grid grid-cols-2 gap-5">
			{#each gamesPage.content as game (game.id)}
				<a href="/library/{game.id}" class="group space-y-3">
					<div
						class="relative aspect-[3/4] rounded-[1.5rem] overflow-hidden bg-surface-container-lowest/80 shadow-[0_8px_32px_rgba(0,0,0,0.05)] group-hover:shadow-2xl group-hover:-translate-y-2 transition-all duration-700"
					>
						{#if game.thumbnailUrl}
							<!-- Ambient Glow Background -->
							<div
								class="absolute inset-0 scale-150 opacity-40 blur-3xl group-hover:opacity-60 transition-all duration-700"
							>
								<img
									src={game.thumbnailUrl}
									alt=""
									class="w-full h-full object-cover"
								/>
							</div>

							<!-- Main Box Art -->
							<img
								src={game.thumbnailUrl}
								alt={game.title}
								class="absolute inset-0 w-full h-full object-contain group-hover:scale-[1.03] transition-transform duration-700"
								loading="lazy"
							/>
						{:else}
							<div
								class="w-full h-full flex items-center justify-center"
							>
								<span
									class="material-symbols-outlined text-4xl text-on-surface-variant opacity-40"
									>casino</span
								>
							</div>
						{/if}

						{#if game.bggRating}
							<div
								class="absolute top-3 right-3 bg-white/90 backdrop-blur px-2.5 py-1 rounded-full flex items-center gap-1 shadow-sm"
							>
								<span
									class="material-symbols-outlined text-[#FF9F1C] text-[14px]"
									style="font-variation-settings: 'FILL' 1;"
									>star</span
								>
								<span class="text-[11px] font-bold font-label"
									>{game.bggRating.toFixed(1)}</span
								>
							</div>
						{/if}

						{#if game.rank}
							<div
								class="absolute top-3 left-3 bg-primary/90 backdrop-blur text-on-primary px-3 py-1 rounded-full flex items-center shadow-sm"
							>
								<span
									class="text-[10px] font-black uppercase tracking-tighter"
									>#{game.rank}</span
								>
							</div>
						{/if}
					</div>
					<div class="px-1">
						<p
							class="text-sm font-bold text-on-surface line-clamp-1 group-hover:text-primary transition-colors"
						>
							{game.title}
						</p>
						<div
							class="flex items-center gap-3 mt-1.5 text-[11px] text-on-surface-variant font-label font-bold"
						>
							{#if game.minPlayers}
								<span
									class="flex items-center gap-1 uppercase tracking-tight"
								>
									<span
										class="material-symbols-outlined text-[14px]"
										>group</span
									>
									{game.minPlayers}{game.maxPlayers
										? `-${game.maxPlayers}`
										: "+"}
								</span>
							{/if}
							{#if game.playTime}
								<span
									class="flex items-center gap-1 uppercase tracking-tight"
								>
									<span
										class="material-symbols-outlined text-[14px]"
										>timer</span
									>
									{game.playTime}M
								</span>
							{/if}
						</div>
					</div>
				</a>
			{/each}
		</div>

		<!-- Infinite Scroll Observer & Loading More state -->
		<div bind:this={observerNode} class="py-10">
			{#if loadingMore}
				<div
					class="grid grid-cols-2 gap-5 animate-in fade-in duration-500"
				>
					{#each { length: 2 } as _}
						<div class="space-y-3">
							<Skeleton class="aspect-[3/4] rounded-[2rem]" />
							<div class="space-y-2 px-1">
								<Skeleton class="h-4 w-3/4 rounded-md" />
								<Skeleton class="h-3 w-1/2 rounded-md" />
							</div>
						</div>
					{/each}
				</div>
			{:else if gamesPage.last && gamesPage.content.length > 0}
				<p
					class="text-center text-[10px] font-black text-on-surface-variant/40 uppercase tracking-[0.2em]"
				>
					You've reached the end of the catalog
				</p>
			{/if}
		</div>
	{/if}

	<!-- Collection grid -->
{:else if filtered.length === 0}
	<div
		class="text-center py-24 bg-surface-container-lowest rounded-[3rem] border border-outline-variant/10 mt-4"
	>
		<span
			class="material-symbols-outlined text-7xl mb-4 block text-primary/10"
			>library_books</span
		>
		<p class="font-bold text-xl">Your collection awaits</p>
		<p class="text-sm text-on-surface-variant mt-2 max-w-xs mx-auto">
			Explore and add games to your library to track your tabletop
			journey.
		</p>
	</div>
{:else}
	<div class="grid grid-cols-2 gap-6 mt-4">
		{#each filtered as ug (ug.id)}
			<a href="/library/{ug.game.id}" class="group space-y-3">
				<div
					class="relative aspect-[3/4] rounded-[1.5rem] overflow-hidden bg-surface-container-lowest/80 shadow-[0_8px_32px_rgba(0,0,0,0.05)] group-hover:shadow-2xl group-hover:-translate-y-2 transition-all duration-700"
				>
					{#if ug.game.thumbnailUrl}
						<!-- Ambient Glow Background -->
						<div
							class="absolute inset-0 scale-150 opacity-40 blur-3xl group-hover:opacity-60 transition-all duration-700"
						>
							<img
								src={ug.game.thumbnailUrl}
								alt=""
								class="w-full h-full object-cover"
							/>
						</div>

						<!-- Main Box Art -->
						<div
							class="relative w-full h-full p-3 flex items-center justify-center"
						>
							<img
								src={ug.game.thumbnailUrl}
								alt={ug.game.title}
								class="max-w-full max-h-full object-contain drop-shadow-[0_12px_24px_rgba(0,0,0,0.2)] group-hover:scale-[1.03] transition-transform duration-700"
								loading="lazy"
							/>
						</div>
					{:else}
						<div
							class="w-full h-full flex items-center justify-center"
						>
							<span
								class="material-symbols-outlined text-4xl text-on-surface-variant opacity-40"
								>casino</span
							>
						</div>
					{/if}

					{#if ug.game.bggRating}
						<div
							class="absolute top-4 right-4 bg-white/95 backdrop-blur px-3 py-1 rounded-full flex items-center gap-1 shadow-md"
						>
							<span
								class="material-symbols-outlined text-primary text-[15px]"
								style="font-variation-settings: 'FILL' 1;"
								>star</span
							>
							<span class="text-[12px] font-label font-black"
								>{ug.game.bggRating.toFixed(1)}</span
							>
						</div>
					{/if}

					{#if ug.isOwned}
						<div
							class="absolute top-4 left-4 bg-tertiary-container text-on-tertiary-container px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest shadow-md"
						>
							Owned
						</div>
					{/if}
					{#if ug.playCount > 0}
						<div
							class="absolute bottom-3 right-3 bg-background/80 backdrop-blur-sm rounded-full px-2 py-0.5 flex items-center gap-1"
						>
							<span
								class="material-symbols-outlined text-[11px] text-primary"
								style="font-variation-settings: 'FILL' 1;"
								>sports_esports</span
							>
							<span
								class="text-[10px] font-extrabold text-on-surface"
								>{ug.playCount}</span
							>
						</div>
					{/if}
				</div>

				<div class="px-2">
					<p
						class="text-sm font-extrabold text-on-surface line-clamp-2 leading-snug group-hover:text-primary transition-colors"
					>
						{ug.game.title}
					</p>
					<div
						class="flex items-center gap-4 mt-2 text-[10px] text-on-surface-variant font-black uppercase tracking-widest opacity-70"
					>
						{#if playerRange(ug)}
							<span class="flex items-center gap-1">
								<span
									class="material-symbols-outlined text-[15px]"
									>group</span
								>
								{playerRange(ug)}
							</span>
						{/if}
						{#if playtime(ug)}
							<span class="flex items-center gap-1">
								<span
									class="material-symbols-outlined text-[15px]"
									>timer</span
								>
								{playtime(ug)}
							</span>
						{/if}
					</div>
				</div>
			</a>
		{/each}
	</div>
{/if}
