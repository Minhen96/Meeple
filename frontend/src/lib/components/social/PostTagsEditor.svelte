<script lang="ts">
	// Tag a game and friends on a post: the two rows plus their search sheets. Used by post
	// create and post edit (FEATURES_COMPLETE 5.4); bind `game` and `friends`, then send
	// them on create, or `tagUpdatePayload(post, { game, friends })` on edit.
	import { fade, fly } from 'svelte/transition';
	import { gamesApi } from '$lib/api/games';
	import { friendsApi } from '$lib/api/friends';
	import { m } from '$lib/i18n';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Spinner from '$lib/components/ui/Spinner.svelte';
	import type { GameSearchResult } from '$lib/types';
	import {
		MAX_TAGGED_FRIENDS,
		toggleTaggedFriend,
		type TaggedFriend,
		type TaggedGame
	} from './postTags';

	interface Props {
		game: TaggedGame | null;
		friends: TaggedFriend[];
	}

	let { game = $bindable(), friends = $bindable() }: Props = $props();

	let showGameSearch = $state(false);
	let showFriendSearch = $state(false);
	let gameQuery = $state('');
	let gameResults = $state<(GameSearchResult & { id: string })[]>([]);
	let gameSearchTimer: ReturnType<typeof setTimeout> | undefined;
	let friendsList = $state<TaggedFriend[] | null>(null);

	function onGameQuery() {
		clearTimeout(gameSearchTimer);
		const q = gameQuery.trim();
		if (q.length < 2) {
			gameResults = [];
			return;
		}
		gameSearchTimer = setTimeout(async () => {
			try {
				// Only games already in our catalogue (with an id) can be tagged
				gameResults = (await gamesApi.search(q)).filter(
					(g): g is GameSearchResult & { id: string } => g.id !== null
				);
			} catch {
				gameResults = [];
			}
		}, 300);
	}

	function pickGame(result: GameSearchResult & { id: string }) {
		game = { id: result.id, title: result.title, thumbnailUrl: result.thumbnailUrl };
		showGameSearch = false;
	}

	async function openFriends() {
		showFriendSearch = true;
		if (friendsList !== null) return;
		try {
			friendsList = (await friendsApi.getFriends(0, 100)).data;
		} catch {
			friendsList = [];
		}
	}
</script>

<div class="flex items-center gap-4 rounded-2xl bg-surface-container-low p-4">
	<button
		type="button"
		onclick={() => (showGameSearch = true)}
		class="flex flex-1 items-center gap-4 text-left"
	>
		<span class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
			<span class="material-symbols-outlined text-[20px]">casino</span>
		</span>
		<span class="flex-1">
			<span class="block text-sm font-bold">{game ? game.title : m('social.create.tagGame')}</span>
			<span class="block text-[10px] uppercase tracking-tighter text-on-surface-variant/60"
				>{m('social.create.whichGame')}</span
			>
		</span>
	</button>
	{#if game}
		<button
			type="button"
			onclick={() => (game = null)}
			class="text-on-surface-variant/60 transition-colors hover:text-on-surface"
			aria-label={m('social.create.removeGame')}
		>
			<span class="material-symbols-outlined text-sm">close</span>
		</button>
	{/if}
</div>

<button
	type="button"
	onclick={openFriends}
	class="flex items-center gap-4 rounded-2xl bg-surface-container-low p-4 text-left transition-all hover:bg-secondary/10 active:scale-[0.98]"
>
	<span
		class="flex h-10 w-10 items-center justify-center rounded-xl bg-secondary/10 text-secondary"
	>
		<span class="material-symbols-outlined text-[20px]">group</span>
	</span>
	<span class="flex-1">
		<span class="block text-sm font-bold">
			{friends.length === 0
				? m('social.create.tagFriends')
				: m('social.create.friendsTagged', { count: friends.length })}
		</span>
		<span class="block text-[10px] uppercase tracking-tighter text-on-surface-variant/60"
			>{m('social.create.whoPlayed')}</span
		>
	</span>
	{#if friends.length > 0}
		<span class="flex -space-x-2">
			{#each friends.slice(0, 3) as friend (friend.id)}
				<Avatar
					src={friend.avatarUrl}
					name={friend.displayName ?? friend.username}
					size="xs"
					className="ring-2 ring-surface"
				/>
			{/each}
		</span>
	{/if}
</button>

<!-- Game search -->
{#if showGameSearch}
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4" transition:fade>
		<button
			type="button"
			class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (showGameSearch = false)}
			aria-label={m('social.create.close')}
		></button>
		<div
			class="relative flex w-full max-w-lg flex-col gap-6 rounded-[2.5rem] bg-surface p-6 shadow-2xl"
			transition:fly={{ y: 20 }}
		>
			<div class="flex items-center justify-between">
				<h3 class="font-headline text-xl font-black">{m('social.create.gameModalTitle')}</h3>
				<button
					type="button"
					onclick={() => (showGameSearch = false)}
					class="flex h-8 w-8 items-center justify-center rounded-full bg-surface-container"
					aria-label={m('social.create.close')}
				>
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>
			<div class="relative">
				<span
					class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant/50"
					>search</span
				>
				<input
					type="search"
					placeholder={m('social.create.searchGames')}
					aria-label={m('social.create.searchGames')}
					bind:value={gameQuery}
					oninput={onGameQuery}
					class="h-12 w-full rounded-2xl bg-surface-container pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
				/>
			</div>
			<div class="max-h-64 space-y-2 overflow-y-auto pb-4 pr-1">
				{#each gameResults as result (result.bggId)}
					<button
						type="button"
						onclick={() => pickGame(result)}
						class="flex w-full items-center gap-3 rounded-xl p-2 transition-colors hover:bg-surface-container"
					>
						{#if result.thumbnailUrl}
							<img
								src={result.thumbnailUrl}
								alt=""
								class="h-10 w-10 rounded-lg bg-surface-container object-cover"
							/>
						{:else}
							<span
								class="flex h-10 w-10 items-center justify-center rounded-lg bg-surface-container"
								><span class="material-symbols-outlined">casino</span></span
							>
						{/if}
						<span class="text-left">
							<span class="block text-sm font-bold leading-tight">{result.title}</span>
							{#if result.yearPublished}<span class="block text-[10px] text-on-surface-variant"
									>{result.yearPublished}</span
								>{/if}
						</span>
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Friend tagging -->
{#if showFriendSearch}
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4" transition:fade>
		<button
			type="button"
			class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (showFriendSearch = false)}
			aria-label={m('social.create.close')}
		></button>
		<div
			class="relative flex w-full max-w-lg flex-col gap-6 rounded-[2.5rem] bg-surface p-6 shadow-2xl"
			transition:fly={{ y: 20 }}
		>
			<div class="flex items-center justify-between">
				<h3 class="font-headline text-xl font-black">{m('social.create.friendsModalTitle')}</h3>
				<button
					type="button"
					onclick={() => (showFriendSearch = false)}
					class="flex h-8 w-8 items-center justify-center rounded-full bg-surface-container"
					aria-label={m('social.create.close')}
				>
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>
			<div class="max-h-80 space-y-2 overflow-y-auto pb-4 pr-1">
				{#if friendsList === null}
					<div class="flex justify-center py-8"><Spinner className="h-6 w-6" /></div>
				{:else if friendsList.length === 0}
					<p class="py-12 text-center text-sm text-on-surface-variant">
						{m('social.create.noFriends')}
					</p>
				{:else}
					{#each friendsList as friend (friend.id)}
						{@const selected = friends.some((f) => f.id === friend.id)}
						{@const full = !selected && friends.length >= MAX_TAGGED_FRIENDS}
						<button
							type="button"
							onclick={() => (friends = toggleTaggedFriend(friends, friend))}
							aria-pressed={selected}
							disabled={full}
							class="flex w-full items-center justify-between rounded-2xl p-3 transition-colors disabled:opacity-40 {selected
								? 'bg-secondary/10'
								: 'hover:bg-surface-container'}"
						>
							<span class="flex items-center gap-3">
								<Avatar
									src={friend.avatarUrl}
									name={friend.displayName ?? friend.username}
									size="sm"
								/>
								<span class="text-sm font-bold">{friend.displayName ?? friend.username}</span>
							</span>
							<span
								class="material-symbols-outlined {selected
									? 'text-secondary'
									: 'text-on-surface-variant/30'}"
							>
								{selected ? 'check_circle' : 'add_circle'}
							</span>
						</button>
					{/each}
				{/if}
			</div>
			<Button fullWidth onclick={() => (showFriendSearch = false)}>{m('social.create.done')}</Button
			>
		</div>
	</div>
{/if}
