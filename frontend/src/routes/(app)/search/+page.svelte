<script lang="ts">
	import { onMount } from 'svelte';
	import { fly } from 'svelte/transition';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { searchApi } from '$lib/api/friends';
	import { getLocale, m } from '$lib/i18n';
	import { currentUser } from '$lib/stores/auth';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import FriendButton from '$lib/components/social/FriendButton.svelte';
	import {
		addRecentSearch,
		loadRecentSearches,
		saveRecentSearches
	} from '$lib/components/social/recentSearches';
	import type { SearchResults } from '$lib/types';
	import { LG_QUERY, matchesMedia } from '$lib/utils/media';

	/**
	 * Full-screen search overlay (SCREENS_AND_STATES 13): games, players, events; 400ms debounce.
	 * Phones list the three groups one under another (3 hits each); from lg they sit side by side
	 * as columns with 6 hits each, games as a cover grid.
	 */
	const DEBOUNCE_MS = 400;

	let query = $state($page.url.searchParams.get('q') ?? '');
	let results = $state<SearchResults | null>(null);
	let loading = $state(false);
	let failed = $state(false);
	// Writable derived: reloaded when the signed-in user changes, edited locally
	let recent = $derived<string[]>($currentUser?.id ? loadRecentSearches($currentUser.id) : []);
	let input = $state<HTMLInputElement>();
	let timer: ReturnType<typeof setTimeout> | undefined;
	let seq = 0;

	const userId = $derived($currentUser?.id ?? null);
	const trimmed = $derived(query.trim());
	const empty = $derived(
		results !== null && results.games.length + results.users.length + results.events.length === 0
	);

	onMount(() => {
		input?.focus();
		if (trimmed) run(trimmed);
		return () => clearTimeout(timer);
	});

	function onInput() {
		clearTimeout(timer);
		if (!trimmed) {
			// Invalidate any search still in flight so it cannot repopulate the cleared overlay.
			seq++;
			results = null;
			loading = false;
			failed = false;
			return;
		}
		loading = true;
		timer = setTimeout(() => run(trimmed), DEBOUNCE_MS);
	}

	async function run(q: string) {
		const mine = ++seq;
		loading = true;
		try {
			const res = await searchApi.search(q, { limit: matchesMedia(LG_QUERY) ? 6 : 3 });
			if (mine !== seq) return;
			results = res;
			failed = false;
		} catch {
			if (mine === seq) failed = true;
		} finally {
			if (mine === seq) loading = false;
		}
	}

	/** Remember the query when the user opens a result. */
	function remember() {
		if (!userId || !trimmed) return;
		recent = addRecentSearch(recent, trimmed);
		saveRecentSearches(userId, recent);
	}

	function useRecent(q: string) {
		query = q;
		void run(q);
	}

	function removeRecent(q: string) {
		recent = recent.filter((r) => r !== q);
		if (userId) saveRecentSearches(userId, recent);
	}

	function clearRecent() {
		recent = [];
		if (userId) saveRecentSearches(userId, []);
	}

	function close() {
		if (history.length > 1) history.back();
		else void goto('/');
	}

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') close();
	}

	const focusRing =
		'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary';

	function formatWhen(iso: string) {
		return new Date(iso).toLocaleDateString(getLocale(), {
			weekday: 'short',
			month: 'short',
			day: 'numeric'
		});
	}
</script>

{#snippet groupHeading(title: string)}
	<h3 class="mb-2 font-label text-xs font-bold uppercase tracking-widest text-on-surface-variant lg:mb-3">
		{title}
	</h3>
{/snippet}

<!-- Desktop only: keeps the three columns in place when a group has no hits -->
{#snippet emptyGroup(title: string)}
	<section class="hidden lg:block lg:rounded-lg lg:bg-surface-container-low lg:p-5" aria-hidden="true">
		{@render groupHeading(title)}
		<p class="py-6 text-center text-sm text-on-surface-variant">{m('social.search.groupEmpty')}</p>
	</section>
{/snippet}

<svelte:head><title>{m('social.search.title')} — Meeple</title></svelte:head>
<svelte:window onkeydown={onKeydown} />

<div
	class="fixed inset-0 md:left-rail lg:left-sidebar z-[60] overflow-y-auto bg-background"
	transition:fly={{ y: -24, duration: 200 }}
>
	<div class="mx-auto max-w-lg md:max-w-xl lg:max-w-6xl px-4 md:px-8 pb-24 pt-4">
		<!-- Search bar -->
		<div
			class="sticky top-0 z-10 -mx-4 md:-mx-8 flex items-center gap-2 bg-background/80 px-4 md:px-8 py-3 backdrop-blur-xl"
		>
			<div class="relative flex-1">
				<span
					class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant"
					>search</span
				>
				<input
					bind:this={input}
					bind:value={query}
					oninput={onInput}
					type="search"
					enterkeyhint="search"
					placeholder={m('social.search.placeholder')}
					aria-label={m('social.search.placeholder')}
					class="w-full rounded-2xl bg-surface-container-highest py-3 pl-10 pr-10 text-sm [&::-webkit-search-cancel-button]:appearance-none text-on-surface outline-none focus:ring-2 focus:ring-primary/40"
				/>
				{#if query}
					<button
						type="button"
						onclick={() => {
							query = '';
							onInput();
							input?.focus();
						}}
						aria-label={m('social.search.clearInput')}
						class="absolute right-2 top-1/2 -translate-y-1/2 rounded-full p-1 text-on-surface-variant hover:bg-surface-container"
					>
						<span class="material-symbols-outlined text-[18px]">close</span>
					</button>
				{/if}
			</div>
			<button
				type="button"
				onclick={close}
				aria-label={m('social.search.close')}
				class="rounded-full p-2 text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
			>
				<span class="material-symbols-outlined">close</span>
			</button>
		</div>

		{#if !trimmed}
			{#if recent.length > 0}
				<section class="mt-4 lg:max-w-xl">
					<div class="mb-2 flex items-center justify-between">
						<h3
							class="font-label text-xs font-bold uppercase tracking-widest text-on-surface-variant"
						>
							{m('social.search.recent')}
						</h3>
						<button type="button" onclick={clearRecent} class="text-xs font-semibold text-primary">
							{m('social.search.clearRecent')}
						</button>
					</div>
					<ul class="space-y-1">
						{#each recent as q (q)}
							<li class="flex items-center gap-2 rounded-xl px-2 hover:bg-surface-container-low">
								<span class="material-symbols-outlined text-[18px] text-on-surface-variant"
									>history</span
								>
								<button
									type="button"
									onclick={() => useRecent(q)}
									class="flex-1 py-2.5 text-left text-sm text-on-surface"
								>
									{q}
								</button>
								<button
									type="button"
									onclick={() => removeRecent(q)}
									aria-label={m('social.search.removeRecent', { query: q })}
									class="rounded-full p-1 text-on-surface-variant hover:text-on-surface"
								>
									<span class="material-symbols-outlined text-[16px]">close</span>
								</button>
							</li>
						{/each}
					</ul>
				</section>
			{/if}
			<p class="mt-12 text-center text-sm text-on-surface-variant">{m('social.search.hint')}</p>
		{:else if loading && !results}
			<div class="mt-4 space-y-6 lg:grid lg:grid-cols-3 lg:gap-6 lg:space-y-0" aria-busy="true">
				{#each [m('social.search.games'), m('social.search.players'), m('social.search.events')] as heading (heading)}
					<section class="space-y-3 lg:rounded-lg lg:bg-surface-container-low lg:p-5">
						<Skeleton class="h-3 w-16" />
						{#each [0, 1] as i (i)}
							<div class="flex items-center gap-3">
								<Skeleton class="h-12 w-12 rounded-xl" />
								<div class="flex-1 space-y-2">
									<Skeleton class="h-3 w-32" /><Skeleton class="h-2.5 w-20" />
								</div>
							</div>
						{/each}
					</section>
				{/each}
			</div>
		{:else if failed && !results}
			<p class="mt-12 text-center text-sm text-on-surface-variant">{m('social.search.failed')}</p>
		{:else if results && empty}
			<p class="mt-12 text-center text-sm text-on-surface-variant">
				{m('social.search.noResults', { query: trimmed })}
			</p>
		{:else if results}
			<div
				class="mt-4 space-y-6 transition-opacity lg:grid lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)_minmax(0,1fr)] lg:items-start lg:gap-6 lg:space-y-0"
				class:opacity-60={loading}
			>
				{#if results.games.length > 0}
					<section class="lg:rounded-lg lg:bg-surface-container-low lg:p-5">
						{@render groupHeading(m('social.search.games'))}
						<ul class="space-y-1 lg:grid lg:grid-cols-2 lg:gap-3 lg:space-y-0">
							{#each results.games as game (game.id)}
								<li>
									<a
										href="/library/{game.id}"
										onclick={remember}
										class="group flex items-center gap-3 rounded-xl p-2 hover:bg-surface-container-low lg:flex-col lg:items-stretch lg:gap-2 lg:rounded-[1.5rem] lg:bg-surface-container-lowest lg:p-2 lg:transition-transform lg:hover:scale-[1.02] lg:hover:bg-surface-container-lowest {focusRing}"
									>
										{#if game.thumbnailUrl}
											<img
												src={game.thumbnailUrl}
												alt=""
												class="h-12 w-12 rounded-xl bg-surface-container object-cover lg:aspect-square lg:h-auto lg:w-full lg:rounded-2xl"
											/>
										{:else}
											<div
												class="flex h-12 w-12 items-center justify-center rounded-xl bg-surface-container text-on-surface-variant lg:aspect-square lg:h-auto lg:w-full lg:rounded-2xl"
											>
												<span class="material-symbols-outlined">casino</span>
											</div>
										{/if}
										<div class="min-w-0 lg:px-1 lg:pb-1">
											<p class="truncate text-sm font-bold text-on-surface">{game.title}</p>
											{#if game.yearPublished}
												<p class="font-label text-xs text-on-surface-variant">
													{game.yearPublished}
												</p>
											{/if}
										</div>
									</a>
								</li>
							{/each}
						</ul>
					</section>
				{:else}
					{@render emptyGroup(m('social.search.games'))}
				{/if}

				{#if results.users.length > 0}
					<section class="lg:rounded-lg lg:bg-surface-container-low lg:p-5">
						{@render groupHeading(m('social.search.players'))}
						<ul class="space-y-1">
							{#each results.users as user, i (user.id)}
								<li
									class="flex items-center gap-3 rounded-xl p-2 hover:bg-surface-container-low lg:hover:bg-surface-container"
								>
									<a
										href="/profile/{user.id}"
										onclick={remember}
										class="flex min-w-0 flex-1 items-center gap-3 rounded-xl {focusRing}"
									>
										<Avatar
											src={user.avatarUrl}
											name={user.displayName ?? user.username}
											size="lg"
										/>
										<div class="min-w-0">
											<p class="truncate text-sm font-bold text-on-surface">
												{user.displayName ?? user.username}
											</p>
											<p class="truncate text-xs text-on-surface-variant">@{user.username}</p>
										</div>
									</a>
									<FriendButton userId={user.id} bind:status={results.users[i].friendshipStatus} />
								</li>
							{/each}
						</ul>
					</section>
				{:else}
					{@render emptyGroup(m('social.search.players'))}
				{/if}

				{#if results.events.length > 0}
					<section class="lg:rounded-lg lg:bg-surface-container-low lg:p-5">
						{@render groupHeading(m('social.search.events'))}
						<ul class="space-y-1">
							{#each results.events as event (event.id)}
								<li>
									<a
										href="/events/{event.id}"
										onclick={remember}
										class="flex items-center gap-3 rounded-xl p-2 hover:bg-surface-container-low lg:hover:bg-surface-container {focusRing}"
									>
										<div
											class="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-xl bg-secondary-container text-on-secondary-container"
										>
											<span class="material-symbols-outlined">event</span>
										</div>
										<div class="min-w-0">
											<p class="truncate text-sm font-bold text-on-surface">{event.title}</p>
											<p class="truncate font-label text-xs text-on-surface-variant">
												{formatWhen(event.scheduledAt)}{event.game ? ` · ${event.game.title}` : ''}
											</p>
										</div>
									</a>
								</li>
							{/each}
						</ul>
					</section>
				{:else}
					{@render emptyGroup(m('social.search.events'))}
				{/if}
			</div>
		{/if}
	</div>
</div>
