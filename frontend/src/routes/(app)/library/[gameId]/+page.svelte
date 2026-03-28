<script lang="ts">
	import type { PageData } from './$types';
	import type { UserGame } from '$lib/types';
	import { gamesApi } from '$lib/api/games';
	import { toast } from 'svelte-sonner';

	interface Props { data: PageData }
	let { data }: Props = $props();

	const game = data.game;
	let myEntry = $state<UserGame | null>(data.myEntry);
	let saving = $state(false);

	async function toggle(flag: 'isOwned' | 'isWishlisted' | 'isFavorited') {
		saving = true;
		try {
			const current = myEntry ?? { isOwned: false, isWishlisted: false, isFavorited: false };
			const updated = await gamesApi.updateCollection(game.id, {
				[flag]: !current[flag]
			});
			myEntry = updated;
		} catch {
			toast.error('Could not update collection');
		} finally {
			saving = false;
		}
	}

	async function remove() {
		if (!myEntry) return;
		saving = true;
		try {
			await gamesApi.removeFromCollection(game.id);
			myEntry = null;
			toast.success('Removed from collection');
		} catch {
			toast.error('Could not remove');
		} finally {
			saving = false;
		}
	}

	const flagLabel = {
		isOwned: { icon: 'check_box', label: 'Own' },
		isWishlisted: { icon: 'bookmark', label: 'Wishlist' },
		isFavorited: { icon: 'favorite', label: 'Favorite' }
	} as const;
</script>

<svelte:head><title>{game.title} — Meeple & Hearth</title></svelte:head>

<!-- Cover image -->
{#if game.imageUrl || game.thumbnailUrl}
	<div class="relative -mx-4 -mt-24 mb-6">
		<img
			src={game.imageUrl ?? game.thumbnailUrl ?? ''}
			alt={game.title}
			class="w-full h-[280px] object-cover"
		/>
		<div class="absolute inset-0 bg-gradient-to-t from-background/90 to-transparent"></div>
		<div class="absolute bottom-4 left-4 right-4">
			<h2 class="text-2xl font-extrabold font-headline text-on-surface">{game.title}</h2>
			{#if game.yearPublished}
				<p class="text-sm text-on-surface-variant">{game.yearPublished}</p>
			{/if}
		</div>
	</div>
{:else}
	<h2 class="text-2xl font-extrabold font-headline mb-1">{game.title}</h2>
	{#if game.yearPublished}
		<p class="text-sm text-on-surface-variant mb-4">{game.yearPublished}</p>
	{/if}
{/if}

<!-- Stats row -->
<div class="grid grid-cols-4 gap-2 mb-6">
	{#each [
		{ label: 'Players', value: game.minPlayers && game.maxPlayers ? `${game.minPlayers}–${game.maxPlayers}` : '—' },
		{ label: 'Time', value: game.minPlaytime ? `${game.minPlaytime}m` : '—' },
		{ label: 'Complexity', value: game.complexityWeight ? game.complexityWeight.toFixed(1) : '—' },
		{ label: 'BGG', value: game.bggRating ? game.bggRating.toFixed(1) : '—' }
	] as stat}
		<div class="bg-surface-container-low rounded-xl p-3 text-center">
			<p class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant">{stat.label}</p>
			<p class="text-base font-extrabold font-headline mt-0.5">{stat.value}</p>
		</div>
	{/each}
</div>

<!-- Collection flags -->
<div class="flex gap-2 mb-6">
	{#each (['isOwned', 'isWishlisted', 'isFavorited'] as const) as flag}
		<button
			onclick={() => toggle(flag)}
			disabled={saving}
			class="flex-1 flex flex-col items-center gap-1 py-3 rounded-xl transition-colors
				{myEntry?.[flag] ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}
				disabled:opacity-50"
		>
			<span class="material-symbols-outlined text-[20px]" style={myEntry?.[flag] ? "font-variation-settings: 'FILL' 1;" : ''}>
				{flagLabel[flag].icon}
			</span>
			<span class="text-xs font-label font-bold">{flagLabel[flag].label}</span>
		</button>
	{/each}
</div>

{#if myEntry}
	<button onclick={remove} disabled={saving} class="w-full text-center text-xs text-on-surface-variant mb-6">
		Remove from collection
	</button>
{/if}

<!-- Description -->
{#if game.description}
	<div>
		<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">About</p>
		<p class="text-sm text-on-surface leading-relaxed line-clamp-6">{game.description}</p>
	</div>
{/if}
