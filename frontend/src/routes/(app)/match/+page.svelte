<script lang="ts">
	import { onMount } from 'svelte';
	import { matchesApi } from '$lib/api/matches';
	import { gamesApi } from '$lib/api/games';
	import { api } from '$lib/api/client';
	import type { ApiResponse, GameDetail } from '$lib/types';
	import MatchSuggestionCard from '$lib/components/match/MatchSuggestionCard.svelte';
	import type { MatchRequest, MatchGroup, GameSearchResult } from '$lib/types';

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
				const res = await api.get<ApiResponse<GameDetail>>(`/api/v1/games/bgg/${selectedGame.bggId}`).catch(() => null);
				gameId = res?.data?.id ?? null;
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

<svelte:head><title>Match — Meeple</title></svelte:head>

<div class="flex items-center justify-between mb-4">
	<h2 class="text-2xl font-extrabold font-headline">Match</h2>
	<button
		onclick={() => showForm = !showForm}
		class="flex items-center gap-1 text-sm font-semibold text-primary"
	>
		<span class="material-symbols-outlined text-lg">{showForm ? 'close' : 'add'}</span>
		{showForm ? 'Cancel' : 'New Request'}
	</button>
</div>

{#if showForm}
	<div class="bg-surface-container-low rounded-2xl p-4 mb-5 space-y-3">
		<p class="font-semibold text-sm">Looking to play…</p>

		<!-- Game search -->
		<div class="relative">
			<input
				type="text"
				bind:value={gameQuery}
				oninput={onGameSearch}
				placeholder="Search for a game"
				class="w-full bg-surface pl-4 pr-4 py-2.5 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary"
			/>
			{#if gameResults.length > 0}
				<div class="absolute z-10 top-full left-0 right-0 mt-1 bg-surface rounded-xl shadow-lg overflow-hidden">
					{#each gameResults.slice(0, 6) as game}
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
				<label class="text-xs text-on-surface-variant mb-1 block">Available from</label>
				<input type="datetime-local" bind:value={availableFrom}
					class="w-full bg-surface px-3 py-2 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary" />
			</div>
			<div>
				<label class="text-xs text-on-surface-variant mb-1 block">Until</label>
				<input type="datetime-local" bind:value={availableTo}
					class="w-full bg-surface px-3 py-2 rounded-xl text-sm outline-none focus:ring-2 focus:ring-primary" />
			</div>
		</div>

		<button
			onclick={submitRequest}
			disabled={!selectedGame || submitting}
			class="w-full bg-primary text-on-primary font-semibold py-2.5 rounded-xl text-sm disabled:opacity-50"
		>
			{submitting ? 'Submitting…' : 'Submit Request'}
		</button>
	</div>
{/if}

<!-- Tabs -->
<div class="flex gap-1 bg-surface-container-low p-1 rounded-xl mb-5">
	{#each [['suggestions', `Suggestions${suggestions.length ? ` (${suggestions.length})` : ''}`], ['requests', 'My Requests']] as [value, label]}
		<button
			onclick={() => tab = value as typeof tab}
			class="flex-1 text-sm font-semibold py-2 rounded-lg transition-colors {tab === value ? 'bg-primary text-on-primary' : 'text-on-surface-variant'}"
		>
			{label}
		</button>
	{/each}
</div>

{#if loading}
	<div class="space-y-3">
		{#each Array(2) as _}
			<div class="h-36 bg-surface-container-low rounded-2xl animate-pulse"></div>
		{/each}
	</div>

{:else if tab === 'suggestions'}
	{#if suggestions.length === 0}
		<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
			<span class="material-symbols-outlined text-5xl">groups</span>
			<p class="font-semibold">No matches yet</p>
			<p class="text-sm">Submit a match request and we'll find friends who want to play the same game.</p>
		</div>
	{:else}
		<div class="space-y-3">
			{#each suggestions as group (group.id)}
				<MatchSuggestionCard {group} onDismiss={onGroupDismiss} />
			{/each}
		</div>
	{/if}

{:else}
	{#if myRequests.length === 0}
		<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
			<span class="material-symbols-outlined text-5xl">sports_esports</span>
			<p class="font-semibold">No active requests</p>
			<p class="text-sm">Tap "New Request" to find friends to play with.</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each myRequests as req (req.id)}
				<div class="flex items-center gap-3 p-3 bg-surface-container-low rounded-xl">
					{#if req.game.thumbnailUrl}
						<img src={req.game.thumbnailUrl} alt={req.game.title}
							class="w-10 h-10 rounded-lg object-cover flex-shrink-0" />
					{/if}
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm truncate">{req.game.title}</p>
						{#if req.availableFrom}
							<p class="text-xs text-on-surface-variant mt-0.5">
								{new Date(req.availableFrom).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
								{#if req.availableTo}
									– {new Date(req.availableTo).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
								{/if}
							</p>
						{:else}
							<p class="text-xs text-on-surface-variant mt-0.5">Any time</p>
						{/if}
					</div>
					<button
						onclick={() => cancelRequest(req.id)}
						class="text-on-surface-variant hover:text-error p-1 transition-colors"
						aria-label="Cancel request"
					>
						<span class="material-symbols-outlined text-lg">close</span>
					</button>
				</div>
			{/each}
		</div>
	{/if}
{/if}
