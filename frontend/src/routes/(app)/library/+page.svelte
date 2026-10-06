<script lang="ts">
	import type { PageData } from "./$types";
	import type { UserGame } from "$lib/types";
	import { gamesApi } from "$lib/api/games";
	import { untrack } from "svelte";
	import { libraryStore, defaultState } from "$lib/stores/library";
	import Skeleton from "$lib/components/ui/Skeleton.svelte";
	import StarRating from "$lib/components/game/StarRating.svelte";
	import { filterCollection, upsertEntry, type LibraryTab } from "$lib/components/game/collection";
	import { m, type MessageKey } from "$lib/i18n";
	import { formatNumber } from "$lib/i18n/format";
	import { goto } from "$app/navigation";
	import { page } from "$app/stores";
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
	let minRating = $derived(store.minRating);
	let sortOption = $derived(store.sortOption);
	let selectedGenre = $derived(store.selectedGenre);

	let query = $state("");

	let showFilters = $state(false);
	let loadingCatalog = $state(false);

	// Local copy so inline rating updates show at once
	let collection = $derived<UserGame[]>(data.collection);

	const filtered = $derived(activeTab === "all" ? [] : filterCollection(collection, activeTab, query));

	// Deep links: /library?tab=wishlist, /library?filter=collection (profile "See all").
	// Applied only when the URL's value changes (never because the tab state changed), so a tab
	// picked by hand is not snapped back to the deep-linked one.
	const URL_TABS: Record<string, LibraryTab> = {
		collection: "owned",
		owned: "owned",
		wishlist: "wishlist",
		wishlisted: "wishlist",
		favorites: "favorites",
		favorited: "favorites",
	};
	let appliedUrlTab: string | null = null;
	$effect(() => {
		const requested = $page.url.searchParams.get("tab") ?? $page.url.searchParams.get("filter");
		if (requested === appliedUrlTab) return;
		appliedUrlTab = requested;
		const tab = requested ? URL_TABS[requested] : undefined;
		untrack(() => {
			if (tab && tab !== store.activeTab) store = { ...store, activeTab: tab };
		});
	});

	/** Keep the address bar on the visible tab (`?tab=` for a shelf, no param for "all"). */
	function syncTabParam(tab: LibraryTab) {
		const url = new URL($page.url);
		url.searchParams.delete("filter");
		if (tab === "all") url.searchParams.delete("tab");
		else url.searchParams.set("tab", tab);
		if (url.search === $page.url.search) return;
		appliedUrlTab = tab === "all" ? null : tab;
		void goto(`${url.pathname}${url.search}${url.hash}`, {
			replaceState: true,
			keepFocus: true,
			noScroll: true,
		});
	}

	let ratingSaving = $state<string | null>(null);
	async function rate(ug: UserGame, rating: number) {
		ratingSaving = ug.game.id;
		try {
			const updated = await gamesApi.updateCollection(ug.game.id, { personalRating: rating });
			collection = upsertEntry(collection, updated);
		} catch {
			toast.error(m("library.rating.saveFailed"));
		} finally {
			ratingSaving = null;
		}
	}

	function selectTab(tab: LibraryTab) {
		store = { ...store, activeTab: tab };
		query = "";
		syncTabParam(tab);
		if (tab === "all") fetchCatalogPage(0);
	}

	const EMPTY: Record<Exclude<LibraryTab, "all">, { icon: string; title: MessageKey; body: MessageKey; browse: boolean }> = {
		owned: { icon: "shelves", title: "library.empty.owned.title", body: "library.empty.owned.body", browse: true },
		wishlist: { icon: "bookmark", title: "library.empty.wishlist.title", body: "library.empty.wishlist.body", browse: true },
		favorites: { icon: "favorite", title: "library.empty.favorites.title", body: "library.empty.favorites.body", browse: false },
	};

	let loadingMore = $state(false);
	let observerNode = $state<HTMLElement | null>(null);

	async function fetchCatalogPage(pageNumber: number, append = false) {
		if (loadingCatalog || loadingMore) return;

		if (append) loadingMore = true;
		else loadingCatalog = true;

		try {
			const result = await gamesApi.browse({
				query: query || undefined,
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
				const currentContent = store.gamesPage?.content ?? [];
				const seen = new Set(currentContent.map((g) => g.id));
				const resultContent = result?.content ?? [];
				const uniqueNew = resultContent.filter((g) => !seen.has(g.id));
				store = {
					...store,
					gamesPage: {
						...result,
						content: [...currentContent, ...uniqueNew],
					},
				};
			} else {
				store = {
					...store,
					gamesPage: result ?? defaultState.gamesPage,
				};
				if (typeof window !== "undefined") {
					window.scrollTo({ top: 0, behavior: "smooth" });
				}
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

	// Initial load: once per visit to the "all" tab with nothing cached. Only the tab is tracked;
	// the fetched page and loading flag are read untracked, so an empty catalog (totalElements 0)
	// does not re-trigger the effect after every fetch. Filters, search and tab clicks fetch
	// explicitly.
	let initialCatalogRequested = false;
	$effect(() => {
		if (activeTab !== "all") return;
		untrack(() => {
			if (initialCatalogRequested || loadingCatalog) return;
			const cached = store.gamesPage;
			if ((cached?.number ?? 0) !== 0 || (cached?.totalElements ?? 0) !== 0) return;
			initialCatalogRequested = true;
			fetchCatalogPage(0);
		});
	});

	// Infinite scroll observer
	$effect(() => {
		if (!observerNode || activeTab !== "all") return;

		const observer = new IntersectionObserver(
			(entries) => {
				if (
					entries[0].isIntersecting &&
					!loadingMore &&
					!loadingCatalog &&
					!gamesPage?.last
				) {
					fetchCatalogPage((gamesPage?.number ?? 0) + 1, true);
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
		if (playTime) return m("library.mine.minutes", { count: playTime });
		return null;
	}

	const tabs: { id: LibraryTab; label: MessageKey }[] = [
		{ id: "all", label: "library.tab.all" },
		{ id: "owned", label: "library.tab.owned" },
		{ id: "wishlist", label: "library.tab.wishlist" },
		{ id: "favorites", label: "library.tab.favorites" },
	];

	// Spotlight data (hardcoded for now as per design); the title is a proper noun.
	const spotlight = {
		title: "Gloomhaven",
		description: "library.spotlight.description" as MessageKey,
		category: "library.spotlight.category" as MessageKey,
		imageUrl:
			"https://lh3.googleusercontent.com/aida-public/AB6AXuD9OrJ1s0wkQqNwd_2YHUbBl6iHCyN8nOBpB4M5CCRPcCrAdiFtFi6vdGS7g51uWG11sEi2A5xZ224aDw5sUYAf5hAOBolULCapAp1U2NWzEUAn_m7t1eK_1q4g-mM8sv8KTArVqCvmLHfz1szDbFToCottMw8Y9l99X7PAbtnF4V5WjZEeNd784ek1C-GJ2U_pw2-CzblT4s91OMRI2OG9cn0CVbWT5_Dsc7UUa3uasDGIn6zx5pkZN2v-oEsMxd98qQvrdP7Nqw0",
	};

	// `value` is the genre filter sent to the API; `label` is what the user sees.
	const categories: { value: string; label: MessageKey }[] = [
		{ value: "Strategy", label: "library.genre.strategy" },
		{ value: "Party", label: "library.genre.party" },
		{ value: "Family", label: "library.genre.family" },
		{ value: "2 Player", label: "library.genre.twoPlayer" },
		{ value: "Abstract", label: "library.genre.abstract" },
	];

	const complexityLevels: { label: MessageKey; min: number; max: number }[] = [
		{ label: "library.complexity.light", min: 1.0, max: 2.0 },
		{ label: "library.complexity.medium", min: 2.1, max: 3.5 },
		{ label: "library.complexity.heavy", min: 3.6, max: 5.0 },
	];

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
			const updated = await gamesApi.updateCollection(hit.id, { isFavorited: true });
			collection = upsertEntry(collection, updated);
			toast.success(m("library.spotlight.saved", { title: spotlight.title }));
		} catch {
			toast.error(m("library.collection.saveFailed"));
		} finally {
			spotlightSaving = false;
		}
	}
</script>

<svelte:head><title>{m("common.nav.library")} — Meeple</title></svelte:head>

<!-- Sticky Unified Header -->
<div
	class="sticky top-14 z-40 bg-background/95 backdrop-blur -mx-4 px-4 pb-3 shadow-sm"
>
	<!-- Tab Bar -->
	<div
		class="flex items-center gap-6 overflow-x-auto hide-scrollbar mb-3"
	>
		{#each tabs as tab (tab.id)}
			<button
				onclick={() => selectTab(tab.id)}
				aria-pressed={activeTab === tab.id}
				class="relative py-4 whitespace-nowrap font-headline font-bold text-sm transition-colors {activeTab ===
				tab.id
					? 'text-primary'
					: 'text-on-surface-variant hover:text-on-surface'}"
			>
				{m(tab.label)}
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
			class="flex-1 flex items-center gap-2 bg-surface-container-low rounded-2xl px-4 py-2 focus-within:ring-2 focus-within:ring-primary/40 transition-all shadow-inner"
		>
			<span
				class="material-symbols-outlined text-[20px] text-on-surface-variant"
				>search</span
			>
			<input
				type="search"
				placeholder={activeTab === "all" ? m("library.search.catalog") : m("library.search.collection")}
				bind:value={query}
				oninput={onQueryInput}
				class="flex-1 bg-transparent text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none py-1"
			/>
		</div>

		<!-- Filter Button -->
		<button
			onclick={() => (showFilters = !showFilters)}
			aria-label={m("library.filters.title")}
			class="relative w-11 h-11 flex items-center justify-center rounded-2xl bg-surface-container-high text-primary hover:bg-surface-variant transition-colors"
		>
			<span class="material-symbols-outlined">tune</span>
			{#if activeFilterCount > 0}
				<span
					class="absolute -top-1 -right-1 w-5 h-5 bg-primary text-on-primary text-[10px] font-black rounded-full flex items-center justify-center ring-2 ring-background animate-in zoom-in"
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
				aria-label={m("library.sort.label")}
				class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
			>
				<option value="">{m("library.sort.label")}</option>
				<option value="recommended">{m("library.sort.recommended")}</option>
				<option value="rank,asc">{m("library.sort.rank")}</option>
				<option value="usersRated,desc">{m("library.sort.popularity")}</option>
				<option value="yearPublished,desc">{m("library.sort.newest")}</option>
				<option value="playTime,asc">{m("library.sort.shortest")}</option>
			</select>
			<div
				class="w-11 h-11 flex items-center justify-center rounded-2xl bg-surface-container-high text-primary"
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
								{m(spotlight.category)}
							</span>
							<h3
								class="text-white font-headline text-2xl font-extrabold mb-1"
							>
								{spotlight.title}
							</h3>
							<p
								class="text-white/70 max-w-md font-body text-xs line-clamp-2"
							>
								{m(spotlight.description)}
							</p>
						</div>
						<div class="flex items-center gap-2 shrink-0">
							<button
								onclick={exploreSpotlight}
								class="bg-white text-on-background px-5 py-2 rounded-full font-bold text-xs hover:bg-primary hover:text-white transition-all active:scale-95 shadow-lg"
							>
								{m("library.spotlight.explore")}
							</button>
							<button
								onclick={saveSpotlight}
								disabled={spotlightSaving}
								aria-label={m("library.spotlight.save")}
								class="w-9 h-9 rounded-full bg-white/10 backdrop-blur-md border border-white/10 flex items-center justify-center text-white hover:bg-white/20 transition-all disabled:opacity-50"
							>
								<span
									class="material-symbols-outlined text-[20px]"
									>bookmark</span
								>
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
			class="relative w-full max-w-lg bg-surface-container-lowest rounded-[2.5rem] shadow-2xl overflow-hidden animate-in slide-in-from-bottom-10 duration-500"
		>
			<div class="p-8">
				<div class="flex items-center justify-between mb-8">
					<h2
						class="font-headline text-2xl font-extrabold text-on-surface"
					>
						{m("library.filters.title")}
					</h2>
					<button
						onclick={() => (showFilters = false)}
						aria-label={m("common.close")}
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
						<span
							class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
							>{m("library.filters.genre")}</span
						>
						<div class="flex flex-wrap gap-2">
							{#each categories as cat (cat.value)}
								<button
									onclick={() => {
										store = {
											...store,
											selectedGenre:
												selectedGenre === cat.value
													? ""
													: cat.value,
										};
										fetchCatalogPage(0);
									}}
									class="px-4 py-2 rounded-2xl text-sm font-bold transition-all {selectedGenre ===
									cat.value
										? 'bg-primary text-on-primary'
										: 'bg-surface-container-low text-on-surface-variant'}"
								>
									{m(cat.label)}
								</button>
							{/each}
						</div>
					</div>

					<!-- Complexity Level -->
					<div class="space-y-3">
						<span
							class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
							>{m("library.filters.complexity")}</span
						>
						<div class="flex flex-wrap gap-2">
							{#each complexityLevels as level (level.label)}
								<button
									onclick={() => {
										store = {
											...store,
											minComplexity: level.min,
											maxComplexity: level.max,
										};
										fetchCatalogPage(0);
									}}
									class="px-4 py-2 rounded-2xl text-sm font-bold transition-all {store.minComplexity ===
										level.min &&
									store.maxComplexity === level.max
										? 'bg-primary text-on-primary shadow-lg shadow-primary/20'
										: 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container-high'}"
								>
									{m(level.label)}
								</button>
							{/each}
						</div>
					</div>

					<!-- Player Count -->
					<div class="space-y-4">
						<div class="flex items-center justify-between">
							<span
								class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
								>{m("library.filters.players")}</span
							>
							<span class="text-[10px] font-bold text-primary"
								>{m("library.filters.minMax")}</span
							>
						</div>
						<div class="grid grid-cols-2 gap-4">
							<input
								type="number"
								min="1"
								max="10"
								placeholder={m("library.filters.min")}
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
								class="bg-surface-container-high rounded-2xl p-4 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
							/>
							<input
								type="number"
								min="1"
								max="50"
								placeholder={m("library.filters.max")}
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
								class="bg-surface-container-high rounded-2xl p-4 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
							/>
						</div>
					</div>

					<!-- Playtime -->
					<div class="space-y-4">
						<div class="flex items-center justify-between">
							<span
								class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
								>{m("library.filters.playtime")}</span
							>
						</div>
						<div class="grid grid-cols-2 gap-4">
							<input
								type="number"
								min="1"
								placeholder={m("library.filters.min")}
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
								class="bg-surface-container-high rounded-2xl p-4 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
							/>
							<input
								type="number"
								min="1"
								placeholder={m("library.filters.max")}
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
								class="bg-surface-container-high rounded-2xl p-4 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
							/>
						</div>
					</div>

					<!-- Rating -->
					<div class="space-y-4">
						<span
							class="text-xs font-black uppercase tracking-widest text-on-surface-variant"
							>{m("library.filters.minRating")}</span
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
										+(e.target as HTMLInputElement).value ||
										undefined,
								};
								fetchCatalogPage(0);
							}}
							class="w-full bg-surface-container-high rounded-2xl p-4 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
						/>
					</div>
				</div>

				<div class="mt-10 flex gap-4">
					<button
						onclick={() => {
							store = {
								...store,
								selectedGenre: "",
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
						{m("library.filters.reset")}
					</button>
					<button
						onclick={() => (showFilters = false)}
						class="flex-[2] py-4 rounded-2xl bg-primary text-on-primary font-bold text-sm shadow-lg shadow-primary/20 active:scale-95 transition-all"
					>
						{m("library.filters.apply")}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

{#if activeTab === "all"}
	<div class="flex items-center justify-between mb-6">
		<div class="flex flex-col">
			<h2 class="font-headline text-xl font-extrabold text-on-surface">
				{m("library.feed.title")}
			</h2>
			<span
				class="text-[10px] font-black text-on-surface-variant uppercase tracking-widest mt-1 opacity-70"
			>
				{m("library.feed.results", { count: formatNumber(gamesPage?.totalElements ?? 0) })}
			</span>
		</div>
	</div>

	{#if loadingCatalog && (gamesPage?.content?.length ?? 0) === 0}
		<div class="grid grid-cols-2 gap-5">
			{#each { length: 6 } as _, i (i)}
				<div class="space-y-3">
					<Skeleton class="aspect-[3/4] rounded-[2rem]" />
					<Skeleton class="h-4 w-3/4 rounded-md" />
					<Skeleton class="h-3 w-1/2 rounded-md" />
				</div>
			{/each}
		</div>
	{:else if (gamesPage?.content?.length ?? 0) === 0}
		<div
			class="text-center py-20 bg-surface-container-lowest rounded-[2rem]"
		>
			<span
				class="material-symbols-outlined text-6xl text-primary/20 mb-4 block"
				>explore_off</span
			>
			{#if store.sortOption === "recommended"}
				<p class="font-bold text-lg">{m("library.feed.noRecommendations")}</p>
				<p class="text-sm text-on-surface-variant mt-1">
					{m("library.feed.noRecommendationsBody")}
				</p>
			{:else}
				<p class="font-bold text-lg">{m("library.feed.empty")}</p>
				<p class="text-sm text-on-surface-variant mt-1">
					{m("library.feed.emptyBody")}
				</p>
			{/if}
		</div>
	{:else}
		<div class="grid grid-cols-2 gap-5">
			{#each gamesPage?.content ?? [] as game (game.id)}
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
									class="icon-filled material-symbols-outlined text-primary-container text-[14px]"
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
									{m("library.mine.minutes", { count: game.playTime })}
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
					{#each { length: 2 } as _, i (i)}
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
					{m("library.feed.end")}
				</p>
			{/if}
		</div>
	{/if}

	<!-- Collection grid -->
{:else if filtered.length === 0}
	{@const empty = EMPTY[activeTab]}
	<div class="text-center py-24 bg-surface-container-lowest rounded-[3rem] mt-4 px-6">
		{#if query.trim().length >= 2 && collection.length > 0}
			<span class="material-symbols-outlined text-7xl mb-4 block text-primary/10">search_off</span>
			<p class="text-sm text-on-surface-variant">{m("library.empty.noMatch", { query: query.trim() })}</p>
		{:else}
			<span class="material-symbols-outlined text-7xl mb-4 block text-primary/10">{empty.icon}</span>
			<p class="font-bold text-xl">{m(empty.title)}</p>
			<p class="text-sm text-on-surface-variant mt-2 max-w-xs mx-auto">{m(empty.body)}</p>
			{#if empty.browse}
				<button
					onclick={() => selectTab("all")}
					class="mt-6 px-6 py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-bold text-sm"
				>
					{m("library.empty.browse")}
				</button>
			{/if}
		{/if}
	</div>
{:else}
	<div class="grid grid-cols-2 gap-6 mt-4">
		{#each filtered as ug (ug.game.id)}
			<div class="space-y-2">
				<a href="/library/{ug.game.id}" class="group block space-y-3">
					<div
						class="relative aspect-[3/4] rounded-[1.5rem] overflow-hidden bg-surface-container-lowest/80 shadow-[0_8px_32px_rgba(0,0,0,0.05)] group-hover:shadow-2xl group-hover:-translate-y-2 transition-all duration-700"
					>
						{#if ug.game.thumbnailUrl}
							<div
								class="absolute inset-0 scale-150 opacity-40 blur-3xl group-hover:opacity-60 transition-all duration-700"
							>
								<img src={ug.game.thumbnailUrl} alt="" class="w-full h-full object-cover" />
							</div>
							<div class="relative w-full h-full p-3 flex items-center justify-center">
								<img
									src={ug.game.thumbnailUrl}
									alt={ug.game.title}
									class="max-w-full max-h-full object-contain drop-shadow-[0_12px_24px_rgba(0,0,0,0.2)] group-hover:scale-[1.03] transition-transform duration-700"
									loading="lazy"
								/>
							</div>
						{:else}
							<div class="w-full h-full flex items-center justify-center">
								<span class="material-symbols-outlined text-4xl text-on-surface-variant opacity-40">casino</span>
							</div>
						{/if}

						<div class="absolute top-3 left-3 flex flex-col items-start gap-1">
							{#if ug.isOwned}
								<span
									class="bg-tertiary-container text-on-tertiary-container px-2.5 py-0.5 rounded-full text-[9px] font-black uppercase tracking-widest shadow-md"
								>
									{m("library.badge.owned")}
								</span>
							{/if}
							{#if ug.isWishlisted}
								<span
									class="bg-secondary-container text-on-secondary-container px-2.5 py-0.5 rounded-full text-[9px] font-black uppercase tracking-widest shadow-md flex items-center gap-0.5"
								>
									<span class="icon-filled material-symbols-outlined text-[11px]">bookmark</span>
									{m("library.badge.wishlist")}
								</span>
							{/if}
						</div>
						{#if ug.isFavorited}
							<span
								class="absolute top-3 right-3 w-7 h-7 rounded-full bg-surface-container-lowest/90 flex items-center justify-center shadow-md"
								aria-label={m("library.badge.favorite")}
							>
								<span class="icon-filled material-symbols-outlined text-[16px] text-primary">favorite</span>
							</span>
						{/if}
						{#if ug.playCount > 0}
							<div
								class="absolute bottom-3 right-3 bg-background/80 backdrop-blur-sm rounded-full px-2 py-0.5 flex items-center gap-1"
							>
								<span class="icon-filled material-symbols-outlined text-[11px] text-primary">sports_esports</span>
								<span class="text-[10px] font-extrabold text-on-surface">{ug.playCount}</span>
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
									<span class="material-symbols-outlined text-[15px]">group</span>
									{playerRange(ug)}
								</span>
							{/if}
							{#if playtime(ug)}
								<span class="flex items-center gap-1">
									<span class="material-symbols-outlined text-[15px]">timer</span>
									{playtime(ug)}
								</span>
							{/if}
						</div>
					</div>
				</a>
				<div class="px-2">
					<StarRating
						rating={ug.personalRating}
						disabled={ratingSaving === ug.game.id}
						onrate={(r) => rate(ug, r)}
					/>
				</div>
			</div>
		{/each}
	</div>
{/if}
