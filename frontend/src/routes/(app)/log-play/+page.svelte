<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { toast } from 'svelte-sonner';
	import type { GameSearchResult } from '$lib/types';
	import { gamesApi } from '$lib/api/games';
	import { m, type MessageKey } from '$lib/i18n';
	import {
		buildLogPlayPayload,
		MAX_DURATION_MINUTES,
		MAX_NOTES,
		MAX_PLAYERS,
		todayInput,
		type LogPlayError
	} from '$lib/components/game/logPlay';

	let query = $state('');
	let results = $state<GameSearchResult[]>([]);
	let selected = $state<GameSearchResult | null>(null);
	let searching = $state(false);
	let logging = $state(false);

	let date = $state(todayInput());
	let durationMinutes = $state('');
	let playerCount = $state('');
	let notes = $state('');
	let formError = $state<LogPlayError | null>(null);

	const ERROR_KEYS: Record<LogPlayError, MessageKey> = {
		futureDate: 'library.logPlay.error.futureDate',
		invalidDate: 'library.logPlay.error.invalidDate',
		duration: 'library.logPlay.error.duration',
		players: 'library.logPlay.error.players',
		notes: 'library.logPlay.error.notes'
	};

	// /log-play?gameId= preselects the game (from game detail)
	onMount(async () => {
		const gameId = $page.url.searchParams.get('gameId');
		if (!gameId) return;
		try {
			const game = await gamesApi.getGame(gameId);
			selected = {
				id: game.id,
				bggId: game.bggId,
				title: game.title,
				yearPublished: game.yearPublished,
				thumbnailUrl: game.thumbnailUrl,
				translatedFrom: null
			};
			query = game.title;
		} catch {
			// Unknown game: fall back to search
		}
	});

	let searchTimer: ReturnType<typeof setTimeout>;

	function onInput() {
		selected = null;
		clearTimeout(searchTimer);
		if (query.trim().length < 2) {
			results = [];
			return;
		}
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

	async function logPlay(e: Event) {
		e.preventDefault();
		if (!selected) return;
		const built = buildLogPlayPayload({ date, notes, durationMinutes, playerCount });
		if ('error' in built) {
			formError = built.error;
			return;
		}
		formError = null;
		logging = true;
		try {
			const gameId = selected.id ?? (await gamesApi.ensureGame(selected.bggId)).id;
			await gamesApi.logPlay(gameId, built.payload);
			toast.success(m('library.logPlay.success', { title: selected.title }));
			history.back();
		} catch {
			toast.error(m('library.logPlay.failed'));
		} finally {
			logging = false;
		}
	}
</script>

<svelte:head><title>{m('library.logPlay.title')} — Meeple</title></svelte:head>

<!-- Header -->
<div class="flex items-center gap-3 mb-8 pt-2">
	<button
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container flex items-center justify-center text-on-surface"
		aria-label={m('library.logPlay.back')}
	>
		<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	</button>
	<h1 class="font-headline text-2xl font-extrabold">{m('library.logPlay.title')}</h1>
</div>

<!-- Search -->
<div class="relative mb-2">
	<div
		class="flex items-center gap-2 bg-surface-container-low rounded-2xl px-4 py-3 focus-within:ring-2 focus-within:ring-primary/20 transition-all"
	>
		<span class="material-symbols-outlined text-[20px] text-on-surface-variant">search</span>
		<input
			type="search"
			placeholder={m('library.logPlay.search')}
			bind:value={query}
			oninput={onInput}
			class="flex-1 bg-transparent text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
		/>
		{#if searching}
			<span class="material-symbols-outlined text-[18px] text-on-surface-variant animate-spin">progress_activity</span>
		{/if}
	</div>

	{#if results.length > 0}
		<div class="absolute top-full left-0 right-0 mt-2 z-50 bg-surface-container-lowest rounded-2xl shadow-xl overflow-hidden">
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
	<p class="text-sm text-on-surface-variant text-center mt-4">{m('library.logPlay.noResults')}</p>
{/if}

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
				<span class="icon-filled material-symbols-outlined text-primary text-[16px]">check_circle</span>
				<span class="text-xs font-bold text-primary">{m('library.logPlay.selected')}</span>
			</div>
		</div>
		<button
			onclick={() => {
				selected = null;
				query = '';
				results = [];
			}}
			class="w-8 h-8 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface-variant flex-shrink-0"
			aria-label={m('library.logPlay.clear')}
		>
			<span class="material-symbols-outlined text-[16px]">close</span>
		</button>
	</div>

	<form onsubmit={logPlay} class="mt-6 space-y-4 pb-48">
		<div class="grid grid-cols-2 gap-3">
			<label class="col-span-2 space-y-1.5">
				<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">{m('library.logPlay.date')}</span>
				<input
					type="date"
					bind:value={date}
					max={todayInput()}
					class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20"
				/>
			</label>
			<label class="space-y-1.5">
				<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">{m('library.logPlay.duration')}</span>
				<input
					type="number"
					inputmode="numeric"
					min="1"
					max={MAX_DURATION_MINUTES}
					bind:value={durationMinutes}
					class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20"
				/>
			</label>
			<label class="space-y-1.5">
				<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">{m('library.logPlay.players')}</span>
				<input
					type="number"
					inputmode="numeric"
					min="1"
					max={MAX_PLAYERS}
					bind:value={playerCount}
					class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20"
				/>
			</label>
			<label class="col-span-2 space-y-1.5">
				<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">{m('library.logPlay.notes')}</span>
				<textarea
					rows="3"
					maxlength={MAX_NOTES}
					bind:value={notes}
					placeholder={m('library.logPlay.notesPlaceholder')}
					class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-sm text-on-surface placeholder:text-on-surface-variant/60 resize-none focus:outline-none focus:ring-2 focus:ring-primary/20"
				></textarea>
			</label>
		</div>

		{#if formError}
			<p class="text-sm text-on-error-container bg-error-container rounded-xl px-4 py-3" role="alert">
				{m(ERROR_KEYS[formError])}
			</p>
		{/if}

		<div class="fixed bottom-28 left-4 right-4 max-w-lg mx-auto">
			<button
				type="submit"
				disabled={logging}
				class="w-full py-4 rounded-2xl bg-gradient-to-br from-primary to-primary-container text-on-primary font-bold text-base shadow-lg shadow-primary/25 active:scale-95 transition-all disabled:opacity-60 flex items-center justify-center gap-2"
			>
				<span class="icon-filled material-symbols-outlined text-[20px]">sports_esports</span>
				{logging ? m('library.logPlay.submitting') : m('library.logPlay.submit')}
			</button>
		</div>
	</form>
{/if}
