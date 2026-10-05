<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import FriendButton from '$lib/components/social/FriendButton.svelte';
	import { peopleSearchHistory, type RecentPerson } from '$lib/stores/peopleSearch';
	import type {
		FriendRequest,
		FriendshipStatus,
		SuggestedUser,
		UserSummaryWithStatus
	} from '$lib/types';
	import { toast } from 'svelte-sonner';

	type Tab = 'discover' | 'requests';
	const SEARCH_DEBOUNCE_MS = 400;

	let tab = $derived<Tab>(
		$page.url.searchParams.get('tab') === 'requests' ? 'requests' : 'discover'
	);

	// Discover
	let searchQuery = $state('');
	let searchResults = $state<UserSummaryWithStatus[]>([]);
	let searching = $state(false);
	let searchError = $state(false);
	let suggestions = $state<SuggestedUser[]>([]);
	let suggestionStatus = $state<Record<string, FriendshipStatus>>({});
	let suggestionsLoading = $state(true);
	let searchTimeout: ReturnType<typeof setTimeout> | undefined;
	let searchSeq = 0;

	// Requests
	let received = $state<FriendRequest[]>([]);
	let sent = $state<FriendRequest[]>([]);
	let requestsLoading = $state(true);
	let requestsError = $state(false);
	let busyRequest = $state<string | null>(null);

	onMount(() => {
		void loadSuggestions();
		void loadRequests();
		return () => clearTimeout(searchTimeout);
	});

	async function loadSuggestions() {
		suggestionsLoading = true;
		try {
			suggestions = await friendsApi.suggestFriends(10);
		} catch {
			suggestions = [];
		} finally {
			suggestionsLoading = false;
		}
	}

	async function loadRequests() {
		requestsLoading = true;
		requestsError = false;
		try {
			const [r, s] = await Promise.all([friendsApi.getReceived(0, 50), friendsApi.getSent(0, 50)]);
			received = r.data;
			sent = s.data;
		} catch {
			requestsError = true;
		} finally {
			requestsLoading = false;
		}
	}

	function onSearchInput() {
		clearTimeout(searchTimeout);
		const q = searchQuery.trim();
		if (!q) {
			searchResults = [];
			searching = false;
			return;
		}
		searching = true;
		searchTimeout = setTimeout(async () => {
			const seq = ++searchSeq;
			try {
				const results = await friendsApi.searchPeople(q, 20);
				if (seq === searchSeq) {
					searchResults = results;
					searchError = false;
				}
			} catch {
				if (seq === searchSeq) searchError = true;
			} finally {
				if (seq === searchSeq) searching = false;
			}
		}, SEARCH_DEBOUNCE_MS);
	}

	function remember(person: RecentPerson) {
		peopleSearchHistory.add(person);
	}

	function selectTab(next: Tab) {
		const url = new URL($page.url);
		if (next === 'requests') url.searchParams.set('tab', 'requests');
		else url.searchParams.delete('tab');
		void goto(url, { replaceState: true, noScroll: true, keepFocus: true });
	}

	async function respond(request: FriendRequest, action: 'accept' | 'decline' | 'cancel') {
		if (busyRequest) return;
		busyRequest = request.id;
		try {
			if (action === 'accept') {
				await friendsApi.accept(request.id);
				toast.success(m('social.friend.accepted'));
			} else if (action === 'decline') {
				await friendsApi.decline(request.id);
				toast.success(m('social.friend.declined'));
			} else {
				await friendsApi.cancel(request.id);
				toast.success(m('social.friend.cancelled'));
			}
			received = received.filter((r) => r.id !== request.id);
			sent = sent.filter((r) => r.id !== request.id);
		} catch (err) {
			toast.error(
				err instanceof ApiRequestError ? errorMessage(err.code) : m('social.friend.failed')
			);
			// The request may have changed elsewhere (accepted, withdrawn): resync
			void loadRequests();
		} finally {
			busyRequest = null;
		}
	}
</script>

<svelte:head><title>{m('social.people.title')} — Meeple</title></svelte:head>

<div class="space-y-6 pb-24">
	<div class="flex items-center justify-between">
		<h2 class="font-headline text-2xl font-extrabold">{m('social.people.title')}</h2>
		<a
			href="/profile/friends"
			class="font-label text-xs font-bold uppercase tracking-widest text-primary"
		>
			{m('social.people.friendsLink')}
		</a>
	</div>

	<!-- Tabs -->
	<div class="flex gap-2 rounded-full bg-surface-container-low p-1" role="tablist">
		{#each [{ id: 'discover', label: m('social.people.tabDiscover') }, { id: 'requests', label: received.length > 0 ? m( 'social.people.tabRequestsCount', { count: received.length } ) : m('social.people.tabRequests') }] as t (t.id)}
			<button
				type="button"
				role="tab"
				aria-selected={tab === t.id}
				onclick={() => selectTab(t.id as Tab)}
				class="flex-1 rounded-full py-2 text-sm font-bold transition-all {tab === t.id
					? 'bg-surface-container-lowest text-on-surface shadow-sm'
					: 'text-on-surface-variant hover:text-on-surface'}"
			>
				{t.label}
			</button>
		{/each}
	</div>

	{#if tab === 'discover'}
		<div class="relative">
			<span
				class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-xl text-on-surface-variant"
				>search</span
			>
			<input
				type="search"
				bind:value={searchQuery}
				oninput={onSearchInput}
				placeholder={m('social.people.searchPlaceholder')}
				aria-label={m('social.people.searchPlaceholder')}
				class="w-full rounded-2xl bg-surface-container-low py-3.5 pl-10 pr-4 text-sm shadow-sm outline-none transition-all focus:ring-2 focus:ring-primary"
			/>
		</div>

		{#if searchQuery.trim()}
			{#if searching && searchResults.length === 0}
				<div class="space-y-3">
					{#each [0, 1, 2] as i (i)}
						<div class="flex items-center gap-3 p-3">
							<Skeleton rounded class="h-12 w-12" />
							<div class="flex-1 space-y-2">
								<Skeleton class="h-3 w-28" /><Skeleton class="h-2.5 w-20" />
							</div>
							<Skeleton class="h-7 w-20 rounded-full" />
						</div>
					{/each}
				</div>
			{:else if searchError}
				<p class="py-12 text-center text-sm text-on-surface-variant">
					{m('social.people.loadFailed')}
				</p>
			{:else if searchResults.length === 0}
				<div class="py-12 text-center">
					<span class="material-symbols-outlined mb-2 text-4xl text-on-surface-variant"
						>person_off</span
					>
					<p class="text-sm text-on-surface-variant">
						{m('social.people.noResults', { query: searchQuery.trim() })}
					</p>
				</div>
			{:else}
				<ul class="space-y-2">
					{#each searchResults as user, i (user.id)}
						<li
							class="flex items-center gap-3 rounded-xl bg-surface-container-low p-3 transition-colors hover:bg-surface-container"
						>
							<a href="/profile/{user.id}" onclick={() => remember(user)}>
								<Avatar src={user.avatarUrl} name={user.displayName ?? user.username} size="lg" />
							</a>
							<a href="/profile/{user.id}" onclick={() => remember(user)} class="min-w-0 flex-1">
								<p class="truncate text-sm font-semibold">{user.displayName ?? user.username}</p>
								<p class="truncate text-xs text-on-surface-variant">@{user.username}</p>
							</a>
							<FriendButton userId={user.id} bind:status={searchResults[i].friendshipStatus} />
						</li>
					{/each}
				</ul>
			{/if}
		{:else}
			{#if $peopleSearchHistory.length > 0}
				<section>
					<div class="mb-3 flex items-center justify-between px-1">
						<h3
							class="font-label text-xs font-bold uppercase tracking-widest text-on-surface-variant"
						>
							{m('social.people.recent')}
						</h3>
						<button
							type="button"
							onclick={() => peopleSearchHistory.clear()}
							class="text-xs font-semibold text-primary hover:underline"
						>
							{m('social.people.clearAll')}
						</button>
					</div>
					<div class="hide-scrollbar -mx-1 flex gap-4 overflow-x-auto px-1 pb-2">
						{#each $peopleSearchHistory as person (person.id)}
							<div class="group relative flex min-w-[72px] flex-col items-center gap-1.5">
								<button
									type="button"
									onclick={() => peopleSearchHistory.remove(person.id)}
									class="absolute -right-1 -top-1 z-10 rounded-full bg-surface-container p-0.5 text-on-surface-variant opacity-0 transition-opacity focus:opacity-100 group-hover:opacity-100"
									aria-label={m('social.people.removeRecent')}
								>
									<span class="material-symbols-outlined text-[14px]">close</span>
								</button>
								<a href="/profile/{person.id}" class="flex flex-col items-center gap-1.5">
									<Avatar
										src={person.avatarUrl}
										name={person.displayName ?? person.username}
										size="xl"
									/>
									<span
										class="line-clamp-1 w-full max-w-[64px] text-center text-[10px] font-semibold"
									>
										{person.displayName ?? person.username}
									</span>
								</a>
							</div>
						{/each}
					</div>
				</section>
			{/if}

			<section>
				<h3
					class="mb-3 px-1 font-label text-xs font-bold uppercase tracking-widest text-on-surface-variant"
				>
					{m('social.people.suggested')}
				</h3>
				{#if suggestionsLoading}
					<div class="space-y-2">
						{#each [0, 1, 2] as i (i)}
							<div class="h-16 animate-pulse rounded-xl bg-surface-container-low"></div>
						{/each}
					</div>
				{:else if suggestions.length === 0}
					<p class="py-8 text-center text-sm text-on-surface-variant">
						{m('social.people.noSuggestions')}
					</p>
				{:else}
					<ul class="space-y-2">
						{#each suggestions as user (user.id)}
							<li
								class="flex items-center gap-3 rounded-xl bg-surface-container-low p-3 transition-colors hover:bg-surface-container"
							>
								<a href="/profile/{user.id}" onclick={() => remember(user)}>
									<Avatar src={user.avatarUrl} name={user.displayName ?? user.username} size="lg" />
								</a>
								<a href="/profile/{user.id}" onclick={() => remember(user)} class="min-w-0 flex-1">
									<p class="truncate text-sm font-semibold">{user.displayName ?? user.username}</p>
									<p class="truncate text-xs text-on-surface-variant">
										{user.sharedGames === 0
											? m('social.people.newMember')
											: user.sharedGames === 1
												? m('social.people.sharedGamesOne')
												: m('social.people.sharedGames', { count: user.sharedGames })}
									</p>
								</a>
								<FriendButton
									userId={user.id}
									status={suggestionStatus[user.id] ?? 'none'}
									onChange={(s) => (suggestionStatus = { ...suggestionStatus, [user.id]: s })}
								/>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		{/if}
	{:else if requestsLoading}
		<div class="space-y-2">
			{#each [0, 1, 2] as i (i)}
				<div class="h-16 animate-pulse rounded-xl bg-surface-container-low"></div>
			{/each}
		</div>
	{:else if requestsError}
		<div class="space-y-3 py-12 text-center">
			<p class="text-sm text-on-surface-variant">{m('social.people.loadFailed')}</p>
			<button type="button" onclick={loadRequests} class="text-sm font-bold text-primary"
				>{m('common.retry')}</button
			>
		</div>
	{:else}
		<section class="space-y-3">
			<h3
				class="px-1 font-label text-xs font-bold uppercase tracking-widest text-on-surface-variant"
			>
				{m('social.people.received')}
			</h3>
			{#if received.length === 0}
				<p
					class="rounded-xl bg-surface-container-low py-6 text-center text-sm text-on-surface-variant"
				>
					{m('social.people.noReceived')}
				</p>
			{:else}
				<ul class="space-y-2">
					{#each received as request (request.id)}
						<li class="flex items-center gap-3 rounded-xl bg-surface-container-low p-3">
							<a href="/profile/{request.sender.id}">
								<Avatar
									src={request.sender.avatarUrl}
									name={request.sender.displayName ?? request.sender.username}
									size="lg"
								/>
							</a>
							<a href="/profile/{request.sender.id}" class="min-w-0 flex-1">
								<p class="truncate text-sm font-semibold">
									{request.sender.displayName ?? request.sender.username}
								</p>
								<p class="truncate text-xs text-on-surface-variant">@{request.sender.username}</p>
							</a>
							<div class="flex gap-2">
								<button
									type="button"
									disabled={busyRequest === request.id}
									onclick={() => respond(request, 'accept')}
									class="rounded-full bg-gradient-to-r from-primary to-primary-container px-4 py-1.5 text-xs font-bold text-on-primary transition-all hover:scale-105 active:scale-95 disabled:opacity-50"
								>
									{m('social.friend.accept')}
								</button>
								<button
									type="button"
									disabled={busyRequest === request.id}
									onclick={() => respond(request, 'decline')}
									class="rounded-full bg-surface-container-high px-4 py-1.5 text-xs font-bold text-on-surface-variant transition-all hover:bg-surface-container-highest active:scale-95 disabled:opacity-50"
								>
									{m('social.friend.decline')}
								</button>
							</div>
						</li>
					{/each}
				</ul>
			{/if}
		</section>

		<section class="space-y-3">
			<h3
				class="px-1 font-label text-xs font-bold uppercase tracking-widest text-on-surface-variant"
			>
				{m('social.people.sent')}
			</h3>
			{#if sent.length === 0}
				<p
					class="rounded-xl bg-surface-container-low py-6 text-center text-sm text-on-surface-variant"
				>
					{m('social.people.noSent')}
				</p>
			{:else}
				<ul class="space-y-2">
					{#each sent as request (request.id)}
						<li class="flex items-center gap-3 rounded-xl bg-surface-container-low p-3">
							<a href="/profile/{request.receiver.id}">
								<Avatar
									src={request.receiver.avatarUrl}
									name={request.receiver.displayName ?? request.receiver.username}
									size="lg"
								/>
							</a>
							<a href="/profile/{request.receiver.id}" class="min-w-0 flex-1">
								<p class="truncate text-sm font-semibold">
									{request.receiver.displayName ?? request.receiver.username}
								</p>
								<p class="truncate text-xs text-on-surface-variant">{m('social.friend.pending')}</p>
							</a>
							<button
								type="button"
								disabled={busyRequest === request.id}
								onclick={() => respond(request, 'cancel')}
								class="rounded-full bg-surface-container-high px-4 py-1.5 text-xs font-bold text-on-surface-variant transition-all hover:bg-surface-container-highest active:scale-95 disabled:opacity-50"
							>
								{m('social.friend.cancel')}
							</button>
						</li>
					{/each}
				</ul>
			{/if}
		</section>
	{/if}
</div>
