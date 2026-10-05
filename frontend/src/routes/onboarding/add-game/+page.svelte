<script lang="ts">
	// SCREENS_AND_STATES section 3.6: debounced search grid, popular games when empty,
	// quick-add sheet, toast, then onboarding is completed.
	import { onMount } from 'svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { gamesApi } from '$lib/api/games';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';
	import { m } from '$lib/i18n';

	interface GridGame {
		id: string | null;
		bggId: number;
		title: string;
		thumbnailUrl: string | null;
		yearPublished: number | null;
	}

	const SEARCH_DEBOUNCE_MS = 400;

	let query = $state('');
	let results = $state<GridGame[]>([]);
	let popular = $state<GridGame[]>([]);
	let loading = $state(true);
	let selected = $state<GridGame | null>(null);
	let adding = $state(false);
	let finishing = $state(false);
	let added = $state<Set<number>>(new Set());

	const searching = $derived(query.trim().length >= 2);
	const shown = $derived(searching ? results : popular);

	onMount(() => {
		gamesApi
			.browse({ sort: 'usersRated,desc' })
			.then((page) => (popular = page.content.slice(0, 12)))
			.catch(() => (popular = []))
			.finally(() => {
				if (!searching) loading = false;
			});
	});

	let timer: ReturnType<typeof setTimeout> | undefined;
	let searchSeq = 0;
	function onInput() {
		clearTimeout(timer);
		if (!searching) {
			results = [];
			loading = false;
			return;
		}
		loading = true;
		const seq = ++searchSeq;
		timer = setTimeout(async () => {
			try {
				const found = await gamesApi.search(query.trim());
				if (seq === searchSeq) results = found;
			} catch {
				if (seq === searchSeq) results = [];
			} finally {
				if (seq === searchSeq) loading = false;
			}
		}, SEARCH_DEBOUNCE_MS);
	}

	async function addSelected() {
		if (!selected) return;
		adding = true;
		try {
			const gameId = selected.id ?? (await gamesApi.ensureGame(selected.bggId)).id;
			await gamesApi.updateCollection(gameId, { isOwned: true });
			added = new Set([...added, selected.bggId]);
			toast.success(m('library.addGame.added'));
			selected = null;
		} catch {
			toast.error(m('library.addGame.failed'));
		} finally {
			adding = false;
		}
	}

	async function finish() {
		if (finishing) return;
		finishing = true;
		try {
			const updated = await usersApi.updateMe({ onboardingCompleted: true });
			setUser(updated);
		} catch {
			// Onboarding re-entry handles a failed save; let the user in either way
		} finally {
			goto('/');
		}
	}
</script>

<svelte:head><title>{m('library.addGame.title')} — Meeple</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-2">{m('library.addGame.title')}</h2>
<p class="text-sm text-on-surface-variant mb-6">{m('library.addGame.subtitle')}</p>

<input
	type="search"
	bind:value={query}
	oninput={onInput}
	placeholder={m('library.addGame.search')}
	class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm mb-4"
/>

{#if !searching}
	<p class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-3">
		{m('library.addGame.popular')}
	</p>
{/if}

{#if loading}
	<div class="grid grid-cols-3 gap-3">
		{#each { length: 9 } as _, i (i)}
			<div class="space-y-2">
				<Skeleton class="aspect-[3/4] rounded-xl" />
				<Skeleton class="h-3 w-3/4 rounded-md" />
			</div>
		{/each}
	</div>
{:else if shown.length === 0}
	{#if searching}
		<p class="text-sm text-on-surface-variant text-center py-8">
			{m('library.addGame.noResults', { query: query.trim() })}
		</p>
	{/if}
{:else}
	<div class="grid grid-cols-3 gap-3">
		{#each shown as game (game.bggId)}
			<button type="button" onclick={() => (selected = game)} class="text-left space-y-1 group">
				<div class="relative aspect-[3/4] rounded-xl overflow-hidden bg-surface-container-high">
					{#if game.thumbnailUrl}
						<img src={game.thumbnailUrl} alt={game.title} class="w-full h-full object-cover" loading="lazy" />
					{:else}
						<div class="w-full h-full flex items-center justify-center">
							<span class="material-symbols-outlined text-on-surface-variant">casino</span>
						</div>
					{/if}
					{#if added.has(game.bggId)}
						<span
							class="absolute top-1.5 right-1.5 bg-tertiary-container text-on-tertiary-container rounded-full w-6 h-6 flex items-center justify-center"
							aria-label={m('library.addGame.inCollection')}
						>
							<span class="material-symbols-outlined text-[16px]">check</span>
						</span>
					{/if}
				</div>
				<p class="text-xs font-bold text-on-surface line-clamp-2 group-hover:text-primary">{game.title}</p>
			</button>
		{/each}
	</div>
{/if}

<div class="pt-8 space-y-3">
	<Button fullWidth loading={finishing} onclick={finish}>{m('library.addGame.done')}</Button>
	<button onclick={finish} class="block w-full text-center text-sm text-on-surface-variant">
		{m('library.addGame.skip')}
	</button>
</div>

{#if selected}
	<div class="fixed inset-0 z-[100] flex items-end sm:items-center justify-center">
		<button
			type="button"
			class="absolute inset-0 bg-black/50 backdrop-blur-sm"
			aria-label={m('common.cancel')}
			onclick={() => (selected = null)}
		></button>
		<div
			class="relative w-full max-w-lg bg-surface-container-lowest rounded-t-[2rem] sm:rounded-[2rem] p-6 space-y-5 shadow-2xl"
			role="dialog"
			aria-modal="true"
		>
			<div class="flex items-center gap-4">
				{#if selected.thumbnailUrl}
					<img src={selected.thumbnailUrl} alt="" class="w-16 h-20 rounded-xl object-cover" />
				{/if}
				<p class="font-headline font-extrabold text-lg text-on-surface">
					{m('library.addGame.sheetTitle', { title: selected.title })}
				</p>
			</div>
			<Button fullWidth loading={adding} onclick={addSelected}>
				{adding ? m('library.addGame.adding') : m('library.addGame.add')}
			</Button>
			<Button variant="secondary" fullWidth onclick={() => (selected = null)}>{m('common.cancel')}</Button>
		</div>
	</div>
{/if}
