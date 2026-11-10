<script lang="ts">
	import { onMount } from 'svelte';
	import { matchesApi } from '$lib/api/matches';
	import { gamesApi } from '$lib/api/games';
	import { api } from '$lib/api/client';
	import type { GameDetail } from '$lib/types';
	import MatchSuggestionCard from '$lib/components/match/MatchSuggestionCard.svelte';
	import PageContainer from '$lib/components/layout/PageContainer.svelte';
	import type { MatchRequest, MatchGroup, GameSearchResult } from '$lib/types';
	import { getLocale, m } from '$lib/i18n';

	const shortDate = (iso: string) =>
		new Date(iso).toLocaleDateString(getLocale(), { month: 'short', day: 'numeric' });

	let tab = $state<'requests' | 'suggestions'>('suggestions');
	let myRequests = $state<MatchRequest[]>([]);
	let suggestions = $state<MatchGroup[]>([]);
	let loading = $state(true);

	// New request form
	let showForm = $state(false);
	let gameQuery = $state('');
	let gameResults = $state<GameSearchResult[]>([]);
	let selectedGame = $state<GameSearchResult | null>(null);
	let availableFrom = $state('');
	let availableTo = $state('');
	let submitting = $state(false);
	let searchTimeout: ReturnType<typeof setTimeout>;

	onMount(async () => {
		const [reqRes, sugRes] = await Promise.all([
			matchesApi.listMyRequests(),
			matchesApi.getSuggestions()
		]);
		myRequests = reqRes;
		suggestions = sugRes;
		loading = false;
		if (sugRes.length > 0) tab = 'suggestions';
	});

	function onGroupDismiss(id: string) {
		suggestions = suggestions.filter(g => g.id !== id);
	}

	async function onGameSearch() {
		clearTimeout(searchTimeout);
		if (!gameQuery.trim()) { gameResults = []; return; }
		searchTimeout = setTimeout(async () => {
			const res = await gamesApi.search(gameQuery);
			gameResults = res;
		}, 300);
	}

	function selectGame(game: GameSearchResult) {
		selectedGame = game;
		gameQuery = game.title;
		gameResults = [];
	}

	async function submitRequest() {
		if (!selectedGame) return;
		submitting = true;
		try {
			// If game not yet in DB, import it first via bggId
			let gameId = selectedGame.id;
			if (!gameId && selectedGame.bggId) {
				const res = await api.get<GameDetail>(`/api/v1/games/bgg/${selectedGame.bggId}`).catch(() => null);
				gameId = res?.id ?? null;
			}
			if (!gameId) return;
			const req = await matchesApi.createRequest({
				gameId,
				availableFrom: availableFrom || undefined,
				availableTo: availableTo || undefined
			});
			myRequests = [req, ...myRequests];
			showForm = false;
			selectedGame = null;
			gameQuery = '';
			availableFrom = '';
			availableTo = '';
			tab = 'requests';
		} finally {
			submitting = false;
		}
	}

	async function cancelRequest(id: string) {
		await matchesApi.cancelRequest(id);
		myRequests = myRequests.filter(r => r.id !== id);
	}
</script>

<svelte:head><title>{m('event.match.title')} — Meeple</title></svelte:head>

<PageContainer width="wide">
<div class="flex items-center justify-between mb-4 md:mb-6">
	<h2 class="text-2xl md:text-4xl md:tracking-tight font-extrabold font-headline">{m('event.match.title')}</h2>
	<button
		onclick={() => showForm = !showForm}
		aria-expanded={showForm}
		class="flex items-center gap-1 text-sm font-semibold text-primary md:px-4 md:py-2 md:rounded-full md:bg-primary/10 md:hover:bg-primary/20 md:transition-colors spring-bounce"
	>
		<span class="material-symbols-outlined text-lg">{showForm ? 'close' : 'add'}</span>
		{showForm ? m('common.cancel') : m('event.match.new')}
	</button>
</div>

{#if showForm}
	<div class="bg-surface-container-low rounded-2xl p-4 mb-5 space-y-3 md:p-6 md:max-w-2xl">
		<p class="font-semibold text-sm">{m('event.match.lookingToPlay')}</p>

		<!-- Game search -->
		<div class="relative">
			<input
				type="text"
				bind:value={gameQuery}
				oninput={onGameSearch}
				placeholder={m('event.match.searchGame')}
				class="w-full bg-surface pl-4 pr-4 py-2.5 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary"
			/>
			{#if gameResults.length > 0}
				<div class="absolute z-10 top-full left-0 right-0 mt-1 bg-surface rounded-xl shadow-lg overflow-hidden">
					{#each gameResults.slice(0, 6) as game (game.bggId)}
						<button
							onclick={() => selectGame(game)}
							class="w-full text-left px-4 py-2.5 text-sm hover:bg-surface-container-low flex items-center gap-2"
						>
							{#if game.thumbnailUrl}
								<img src={game.thumbnailUrl} alt="" class="w-7 h-7 rounded object-cover flex-shrink-0" />
							{/if}
							<span>{game.title}</span>
							{#if game.yearPublished}
								<span class="text-on-surface-variant ml-auto text-xs">{game.yearPublished}</span>
							{/if}
						</button>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Time window -->
		<div class="grid grid-cols-2 gap-2">
			<div>
				<label for="match-availableFrom" class="text-xs text-on-surface-variant mb-1 block">{m('event.match.availableFrom')}</label>
				<input id="match-availableFrom" type="datetime-local" bind:value={availableFrom}
					class="w-full bg-surface px-3 py-2 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary" />
			</div>
			<div>
				<label for="match-availableTo" class="text-xs text-on-surface-variant mb-1 block">{m('event.match.until')}</label>
				<input id="match-availableTo" type="datetime-local" bind:value={availableTo}
					class="w-full bg-surface px-3 py-2 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary" />
			</div>
		</div>

		<button
			onclick={submitRequest}
			disabled={!selectedGame || submitting}
			class="w-full bg-primary text-on-primary font-semibold py-2.5 rounded-xl text-sm disabled:opacity-50"
		>
			{submitting ? m('event.match.submitting') : m('event.match.submit')}
		</button>
	</div>
{/if}

<!-- Tabs -->
<div class="flex gap-1 bg-surface-container-low p-1 rounded-xl mb-5 md:max-w-md md:mb-6">
	{#each [['suggestions', suggestions.length ? m('event.match.tab.suggestionsCount', { count: suggestions.length }) : m('event.match.tab.suggestions')], ['requests', m('event.match.tab.requests')]] as [value, label] (value)}
		<button
			onclick={() => tab = value as typeof tab}
			aria-pressed={tab === value}
			class="flex-1 text-sm font-semibold py-2 rounded-lg transition-colors {tab === value ? 'bg-primary text-on-primary' : 'text-on-surface-variant md:hover:bg-surface-container-high md:hover:text-on-surface'}"
		>
			{label}
		</button>
	{/each}
</div>

{#if loading}
	<div class="space-y-3 md:space-y-0 md:grid md:grid-cols-2 xl:grid-cols-3 md:gap-4">
		{#each Array(2) as _, i (i)}
			<div class="h-36 bg-surface-container-low rounded-2xl animate-pulse"></div>
		{/each}
	</div>

{:else if tab === 'suggestions'}
	{#if suggestions.length === 0}
		{@render emptyState('groups', m('event.match.empty.suggestionsTitle'), m('event.match.empty.suggestionsBody'))}
	{:else}
		<div class="space-y-3 md:space-y-0 md:grid md:grid-cols-2 xl:grid-cols-3 md:gap-4 md:items-stretch">
			{#each suggestions as group (group.id)}
				<MatchSuggestionCard {group} onDismiss={onGroupDismiss} />
			{/each}
		</div>
	{/if}

{:else}
	{#if myRequests.length === 0}
		{@render emptyState('sports_esports', m('event.match.empty.requestsTitle'), m('event.match.empty.requestsBody'))}
	{:else}
		<div class="space-y-2 md:space-y-0 md:grid md:grid-cols-2 xl:grid-cols-3 md:gap-3">
			{#each myRequests as req (req.id)}
				<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl md:p-4 md:hover:bg-surface-container md:transition-colors">
					{#if req.game.thumbnailUrl}
						<img src={req.game.thumbnailUrl} alt={req.game.title}
							class="w-10 h-10 rounded-lg object-cover flex-shrink-0" />
					{/if}
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm truncate">{req.game.title}</p>
						{#if req.availableFrom}
							<p class="text-xs text-on-surface-variant mt-0.5">
								{req.availableTo
									? m('event.match.range', { start: shortDate(req.availableFrom), end: shortDate(req.availableTo) })
									: shortDate(req.availableFrom)}
							</p>
						{:else}
							<p class="text-xs text-on-surface-variant mt-0.5">{m('event.match.anyTime')}</p>
						{/if}
					</div>
					<button
						onclick={() => cancelRequest(req.id)}
						class="text-on-surface-variant hover:text-error p-1 transition-colors md:rounded-full md:hover:bg-error/10"
						aria-label={m('event.match.cancelRequest')}
					>
						<span class="material-symbols-outlined text-lg">close</span>
					</button>
				</div>
			{/each}
		</div>
	{/if}
{/if}
</PageContainer>

<!-- Empty state: plain on phones; from md a tonal panel with an icon badge and a CTA -->
{#snippet emptyState(icon: string, title: string, body: string)}
	<div
		class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant md:bg-surface-container-low md:rounded-lg md:px-8 md:py-20"
	>
		<span class="material-symbols-outlined text-5xl md:w-20 md:h-20 md:rounded-full md:bg-primary/10 md:text-primary md:flex md:items-center md:justify-center md:text-4xl md:mb-2" aria-hidden="true">{icon}</span>
		<p class="font-semibold md:text-lg md:font-headline md:font-bold md:text-on-surface">{title}</p>
		<p class="text-sm md:max-w-sm">{body}</p>
		{#if !showForm}
			<button
				type="button"
				onclick={() => (showForm = true)}
				class="hidden md:inline-flex items-center gap-1 mt-3 px-5 py-2.5 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary text-sm font-label font-bold shadow-[0_8px_24px_rgba(137,81,0,0.20)] hover:scale-[1.02] transition-transform spring-bounce"
			>
				<span class="material-symbols-outlined text-[18px]" aria-hidden="true">add</span>
				{m('event.match.new')}
			</button>
		{/if}
	</div>
{/snippet}
