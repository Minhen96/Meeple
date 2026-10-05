<script lang="ts">
	// Step 4 — Find friends (SCREENS_AND_STATES section 3.5): suggestions, username search and
	// an inline "Add Friend" button that turns into "Pending" immediately (optimistic).
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import SkeletonPattern from '$lib/components/ui/SkeletonPattern.svelte';
	import { ApiRequestError } from '$lib/api/client';
	import { friendsApi } from '$lib/api/friends';
	import { errorMessage, m } from '$lib/i18n';
	import type { User } from '$lib/types';
	import { nextStepPath } from '../onboarding';

	const SEARCH_DEBOUNCE_MS = 400;
	const next = nextStepPath('/onboarding/find-friends') ?? '/';

	let suggestions = $state<User[]>([]);
	let results = $state<User[]>([]);
	let loading = $state(true);
	let searching = $state(false);
	let query = $state('');
	let requested = $state<Record<string, boolean>>({});
	let searchTimer: ReturnType<typeof setTimeout> | undefined;
	let searchSeq = 0;

	const showingSearch = $derived(query.trim().length >= 2);
	const list = $derived(showingSearch ? results : suggestions);

	async function loadSuggestions() {
		try {
			const page = await friendsApi.getSuggestions(0, 10);
			suggestions = page.data ?? [];
		} catch {
			suggestions = [];
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		void loadSuggestions();
		return () => clearTimeout(searchTimer);
	});

	function onSearchInput() {
		clearTimeout(searchTimer);
		const q = query.trim();
		if (q.length < 2) {
			results = [];
			searching = false;
			return;
		}
		searching = true;
		const seq = ++searchSeq;
		searchTimer = setTimeout(async () => {
			try {
				const page = await friendsApi.searchUsers(q, 0, 20);
				if (seq === searchSeq) results = page.data ?? [];
			} catch {
				if (seq === searchSeq) results = [];
			} finally {
				if (seq === searchSeq) searching = false;
			}
		}, SEARCH_DEBOUNCE_MS);
	}

	async function addFriend(user: User) {
		requested = { ...requested, [user.id]: true };
		try {
			await friendsApi.sendRequest(user.id);
		} catch (err) {
			const code = err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR';
			// Already pending / already friends: keep the chip; anything else rolls back
			if (code !== 'ALREADY_REQUESTED' && code !== 'ALREADY_FRIENDS' && code !== 'CONFLICT') {
				const rest = { ...requested };
				delete rest[user.id];
				requested = rest;
				toast.error(errorMessage(code));
			}
		}
	}
</script>

<svelte:head><title>{m('account.findFriends.title')} — {m('common.appName')}</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">{m('account.findFriends.title')}</h2>

<label for="find-friends-search" class="sr-only">{m('account.findFriends.searchLabel')}</label>
<div class="relative mb-4">
	<span class="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant/60 text-[18px]">search</span>
	<input
		id="find-friends-search"
		type="search"
		bind:value={query}
		oninput={onSearchInput}
		placeholder={m('account.findFriends.searchPlaceholder')}
		autocapitalize="none"
		class="w-full bg-surface-container-highest rounded-xl pl-11 pr-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>
</div>

{#if !showingSearch}
	<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant px-1 mb-2">
		{m('account.findFriends.suggested')}
	</p>
{/if}

{#if loading || searching}
	<SkeletonPattern variant="user" count={3} />
{:else if list.length === 0}
	<p class="text-sm text-on-surface-variant text-center py-8">
		{showingSearch ? m('account.findFriends.noResults', { query: query.trim() }) : m('account.findFriends.empty')}
	</p>
{:else}
	<ul class="space-y-2">
		{#each list as person (person.id)}
			<li class="flex items-center gap-3 p-3 rounded-2xl bg-surface-container-low">
				<Avatar src={person.avatarUrl} name={person.displayName || person.username} size="lg" />
				<div class="flex-1 min-w-0">
					<p class="text-sm font-bold text-on-surface truncate">{person.displayName || person.username}</p>
					<p class="text-xs text-on-surface-variant truncate">@{person.username}</p>
				</div>
				{#if requested[person.id]}
					<span class="text-xs font-bold px-3 py-2 rounded-full bg-secondary-container text-on-secondary-container flex items-center gap-1">
						<span class="material-symbols-outlined text-[16px]" aria-hidden="true">schedule</span>
						{m('account.findFriends.pending')}
					</span>
				{:else}
					<Button size="sm" onclick={() => addFriend(person)}>{m('account.findFriends.add')}</Button>
				{/if}
			</li>
		{/each}
	</ul>
{/if}

<div class="pt-8">
	<Button fullWidth onclick={() => goto(next)}>{m('common.continue')}</Button>
</div>
