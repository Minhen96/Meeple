<!-- Optional game for an event (SCREENS section 6.5 item 1): search, pick, or leave empty. -->
<script lang="ts">
	import { onDestroy } from 'svelte';
	import { gamesApi } from '$lib/api/games';
	import { m } from '$lib/i18n';
	import type { GameSearchResult } from '$lib/types';
	import { eventErrorMessage } from './eventState';
	import type { PickedGame } from './eventForm';

	interface Props {
		game: PickedGame | null;
		onChange: (game: PickedGame | null) => void;
	}

	let { game, onChange }: Props = $props();

	const SEARCH_DEBOUNCE_MS = 300;
	const MAX_RESULTS = 6;

	let query = $state('');
	let results = $state<GameSearchResult[]>([]);
	let busy = $state(false);
	let error = $state<string | null>(null);
	let timer: ReturnType<typeof setTimeout> | undefined;
	let searchId = 0;

	onDestroy(() => clearTimeout(timer));

	function onInput() {
		clearTimeout(timer);
		error = null;
		const q = query.trim();
		if (!q) {
			results = [];
			return;
		}
		timer = setTimeout(async () => {
			const id = ++searchId;
			try {
				const found = await gamesApi.search(q);
				if (id === searchId) results = found.slice(0, MAX_RESULTS);
			} catch (err) {
				if (id === searchId) error = eventErrorMessage(err);
			}
		}, SEARCH_DEBOUNCE_MS);
	}

	async function pick(result: GameSearchResult) {
		busy = true;
		error = null;
		try {
			// Games not yet cached locally are imported by BGG id first
			const id = result.id ?? (await gamesApi.ensureGame(result.bggId)).id;
			onChange({ id, title: result.title, thumbnailUrl: result.thumbnailUrl });
			query = '';
			results = [];
		} catch (err) {
			error = eventErrorMessage(err);
		} finally {
			busy = false;
		}
	}
</script>

{#if game}
	<div class="flex items-center gap-3 bg-surface-container-high rounded-lg p-3">
		{#if game.thumbnailUrl}
			<img src={game.thumbnailUrl} alt="" class="w-12 h-12 rounded-lg object-cover flex-shrink-0" />
		{:else}
			<div class="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center text-primary flex-shrink-0">
				<span class="material-symbols-outlined" aria-hidden="true">casino</span>
			</div>
		{/if}
		<p class="flex-1 min-w-0 font-bold text-on-surface truncate">{game.title}</p>
		<button
			type="button"
			onclick={() => onChange(null)}
			class="w-9 h-9 rounded-full bg-surface-container-highest flex items-center justify-center text-on-surface-variant spring-bounce"
			aria-label={m('event.form.gameClear')}
		>
			<span class="material-symbols-outlined text-[18px]" aria-hidden="true">close</span>
		</button>
	</div>
{:else}
	<div class="relative">
		<span
			class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-[18px]"
			aria-hidden="true">search</span
		>
		<input
			type="search"
			bind:value={query}
			oninput={onInput}
			disabled={busy}
			placeholder={m('event.form.gameSearch')}
			aria-label={m('event.form.gameSearch')}
			class="w-full bg-surface-container-highest rounded-lg pl-10 pr-4 py-3 text-sm text-on-surface placeholder:text-on-surface-variant/60 focus:outline-none focus:ring-2 focus:ring-primary/30"
		/>
		{#if results.length > 0}
			<ul class="absolute z-20 top-full left-0 right-0 mt-1 bg-surface-container-lowest rounded-lg shadow-lg overflow-hidden">
				{#each results as result (result.bggId)}
					<li>
						<button
							type="button"
							onclick={() => pick(result)}
							class="w-full text-left px-4 py-2.5 text-sm hover:bg-surface-container-low flex items-center gap-2"
						>
							{#if result.thumbnailUrl}
								<img src={result.thumbnailUrl} alt="" class="w-7 h-7 rounded object-cover flex-shrink-0" />
							{/if}
							<span class="flex-1 truncate">{result.title}</span>
							{#if result.yearPublished}
								<span class="text-on-surface-variant text-xs">{result.yearPublished}</span>
							{/if}
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
	{#if error}
		<p class="mt-2 text-xs text-error" role="alert">{error}</p>
	{/if}
{/if}
