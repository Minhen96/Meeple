<script lang="ts">
	import type { GameSearchResult } from '$lib/types';
	import { gamesApi } from '$lib/api/games';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';

	let query = $state('');
	let results = $state<GameSearchResult[]>([]);
	let selected = $state<GameSearchResult | null>(null);
	let searching = $state(false);
	let logging = $state(false);

	let searchTimer: ReturnType<typeof setTimeout>;

	function onInput() {
		selected = null;
		clearTimeout(searchTimer);
		if (query.trim().length < 2) { results = []; return; }
		searching = true;
		searchTimer = setTimeout(async () => {
			try {
				results = await gamesApi.search(query.trim());
			} catch {
				results = [];
			} finally {
				searching = false;
			}
		}, 350);
	}

	function pick(game: GameSearchResult) {
		selected = game;
		results = [];
		query = game.title;
	}

	async function logPlay() {
		if (!selected?.id) return;
		logging = true;
		try {
			await gamesApi.logPlay(selected.id);
			toast.success(`Play logged for ${selected.title}!`);
			goto(-1 as any);
		} catch {
			toast.error('Could not log play. Try again.');
		} finally {
			logging = false;
		}
	}
</script>

<svelte:head><title>Log a Play — Meeple</title></svelte:head>

<!-- Header -->
<div class="flex items-center gap-3 mb-8 pt-2">
	<button
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container flex items-center justify-center text-on-surface"
		aria-label="Go back"
	>
		<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	</button>
	<h1 class="font-headline text-2xl font-extrabold">Log a Play</h1>
</div>

<!-- Search -->
<div class="relative mb-2">
	<div class="flex items-center gap-2 bg-surface-container-low rounded-2xl px-4 py-3 focus-within:ring-2 focus-within:ring-primary/20 transition-all">
		<span class="material-symbols-outlined text-[20px] text-on-surface-variant">search</span>
		<input
			type="search"
			placeholder="Search for a game..."
			bind:value={query}
			oninput={onInput}
			class="flex-1 bg-transparent text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
			autofocus
		/>
		{#if searching}
			<span class="material-symbols-outlined text-[18px] text-on-surface-variant animate-spin">progress_activity</span>
		{/if}
	</div>

	<!-- Results dropdown -->
	{#if results.length > 0}
		<div class="absolute top-full left-0 right-0 mt-2 z-50 bg-surface-container-lowest rounded-2xl shadow-xl border border-outline-variant/10 overflow-hidden">
			{#each results as game (game.bggId)}
				<button
					onclick={() => pick(game)}
					class="w-full flex items-center gap-3 px-4 py-3 hover:bg-surface-container transition-colors text-left"
				>
					{#if game.thumbnailUrl}
						<img src={game.thumbnailUrl} alt={game.title} class="w-10 h-10 rounded-xl object-cover flex-shrink-0" />
					{:else}
						<div class="w-10 h-10 rounded-xl bg-surface-container-high flex items-center justify-center flex-shrink-0">
							<span class="material-symbols-outlined text-[18px] text-on-surface-variant">casino</span>
						</div>
					{/if}
					<div class="flex-1 min-w-0">
						<p class="font-bold text-sm text-on-surface truncate">{game.title}</p>
						{#if game.yearPublished}
							<p class="text-xs text-on-surface-variant font-label">{game.yearPublished}</p>
						{/if}
					</div>
				</button>
			{/each}
		</div>
	{/if}
</div>

{#if query.length >= 2 && !searching && results.length === 0 && !selected}
	<p class="text-sm text-on-surface-variant text-center mt-4">No games found. Try a different name.</p>
{/if}

<!-- Selected game card -->
{#if selected}
	<div class="mt-6 bg-surface-container-low rounded-3xl p-5 flex items-center gap-4">
		{#if selected.thumbnailUrl}
			<img src={selected.thumbnailUrl} alt={selected.title} class="w-20 h-20 rounded-2xl object-cover flex-shrink-0 shadow-md" />
		{:else}
			<div class="w-20 h-20 rounded-2xl bg-surface-container-high flex items-center justify-center flex-shrink-0">
				<span class="material-symbols-outlined text-3xl text-on-surface-variant opacity-40">casino</span>
			</div>
		{/if}
		<div class="flex-1 min-w-0">
			<p class="font-headline font-extrabold text-lg text-on-surface leading-tight">{selected.title}</p>
			{#if selected.yearPublished}
				<p class="text-xs text-on-surface-variant font-label mt-1">{selected.yearPublished}</p>
			{/if}
			<div class="flex items-center gap-1.5 mt-2">
				<span class="material-symbols-outlined text-primary text-[16px]" style="font-variation-settings: 'FILL' 1;">check_circle</span>
				<span class="text-xs font-bold text-primary">Selected</span>
			</div>
		</div>
		<button
			onclick={() => { selected = null; query = ''; results = []; }}
			class="w-8 h-8 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface-variant flex-shrink-0"
			aria-label="Clear selection"
		>
			<span class="material-symbols-outlined text-[16px]">close</span>
		</button>
	</div>
{/if}

<!-- Log Play CTA -->
{#if selected}
	<div class="fixed bottom-28 left-4 right-4 max-w-lg mx-auto">
		<button
			onclick={logPlay}
			disabled={logging}
			class="w-full py-4 rounded-2xl bg-gradient-to-br from-primary to-primary-container text-on-primary font-bold text-base shadow-lg shadow-primary/25 active:scale-95 transition-all disabled:opacity-60 flex items-center justify-center gap-2"
		>
			<span class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1;">sports_esports</span>
			{logging ? 'Logging...' : 'Log Play'}
		</button>
	</div>
{/if}
