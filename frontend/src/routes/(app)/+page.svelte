<script lang="ts">
	import { onMount, untrack } from 'svelte';
	import MatchSuggestionCard from '$lib/components/match/MatchSuggestionCard.svelte';
	import PostCard from '$lib/components/social/PostCard.svelte';
	import EventCardCompact from '$lib/components/event/EventCardCompact.svelte';
	import ActivityItem from '$lib/components/social/ActivityItem.svelte';
	import PostCardSkeleton from '$lib/components/social/PostCardSkeleton.svelte';
	import Spinner from '$lib/components/ui/Spinner.svelte';
	import {
		CursorPager,
		preferExisting,
		watchScrollDepth,
		type PagerState
	} from '$lib/components/social/cursorPager';
	import { daysUntil, greetingKey } from '$lib/components/social/format';
	import { postsApi } from '$lib/api/posts';
	import { m } from '$lib/i18n';
	import type { FeedItem, MatchGroup } from '$lib/types';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const itemKey = (item: FeedItem) =>
		item.kind === 'post' ? `p:${item.post.id}` : `a:${item.activity.id}`;

	let feed = $state<PagerState<FeedItem>>({
		items: [],
		loading: true,
		loadingMore: false,
		hasMore: true,
		error: null,
		loaded: false
	});
	let pager: CursorPager<FeedItem> | null = null;
	let dismissed = $state<string[]>([]);

	const matchSuggestions = $derived(
		data.matchSuggestions.filter((g: MatchGroup) => !dismissed.includes(g.id))
	);
	const name = $derived(
		data.user?.displayName || data.user?.username || m('social.home.fallbackName')
	);
	const nextEvent = $derived(data.upcomingEvents[0] ?? null);
	const nextInDays = $derived(nextEvent ? daysUntil(nextEvent.scheduledAt) : null);
	const subtitle = $derived(
		nextInDays === null
			? m('social.home.noUpcoming')
			: nextInDays === 0
				? m('social.home.nextSessionToday')
				: nextInDays === 1
					? m('social.home.nextSessionTomorrow')
					: m('social.home.nextSessionDays', { days: nextInDays })
	);
	const emptyKind = $derived(
		data.friendCount > 0 ? 'quiet' : data.pendingSentCount > 0 ? 'pending' : 'noFriends'
	);

	// A fresh pager per load (navigation back to Home, invalidation)
	$effect(() => {
		const initial = data.feed ?? undefined;
		untrack(() => {
			feed = { ...feed, items: [] };
			const p = new CursorPager<FeedItem>(
				(cursor) => postsApi.getFeedPage(cursor, 20),
				itemKey,
				// Keep the (possibly locally edited) items already on screen when a page is appended
				(state) => (feed = { ...state, items: preferExisting(feed.items, state.items, itemKey) }),
				initial
			);
			pager = p;
			if (!initial) void p.loadMore();
		});
	});

	onMount(() =>
		watchScrollDepth(() => {
			if (pager && feed.loaded && feed.hasMore && !feed.loadingMore && !feed.error)
				void pager.loadMore();
		})
	);

	function removePost(postId: string) {
		pager?.update((items) => items.filter((i) => !(i.kind === 'post' && i.post.id === postId)));
	}


</script>

<svelte:head>
	<title>{m('social.home.title')} — Meeple</title>
</svelte:head>

<div class="space-y-8">
	<!-- Greeting -->
	<section class="space-y-1">
		<h2 class="font-headline text-3xl font-extrabold tracking-tight text-on-surface">
			{m(greetingKey(new Date().getHours()), { name })}
		</h2>
		<p class="text-sm font-medium text-on-surface-variant">{subtitle}</p>
	</section>

	<!-- Match suggestions: first card plus a "+N more" chip -->
	{#if matchSuggestions.length > 0}
		<section class="space-y-2">
			<MatchSuggestionCard
				group={matchSuggestions[0]}
				onDismiss={(id) => (dismissed = [...dismissed, id])}
			/>
			{#if matchSuggestions.length > 1}
				<a
					href="/match"
					class="inline-flex items-center gap-1 rounded-full bg-secondary-container px-3 py-1 font-label text-xs font-bold text-on-secondary-container"
				>
					{m('social.home.moreMatches', { count: matchSuggestions.length - 1 })}
					<span class="material-symbols-outlined text-[14px]">chevron_right</span>
				</a>
			{/if}
		</section>
	{/if}

	<!-- Upcoming events: hidden entirely when there are none -->
	{#if data.upcomingEvents.length > 0}
		<section class="space-y-4">
			<div class="flex items-center justify-between">
				<h3 class="font-headline text-lg font-bold">{m('social.home.upcomingTitle')}</h3>
				<a
					href="/events?view=calendar"
					class="font-label text-xs font-bold uppercase tracking-widest text-primary"
				>
					{m('social.home.viewCalendar')}
				</a>
			</div>
			<div class="hide-scrollbar -mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
				{#each data.upcomingEvents.slice(0, 6) as event (event.id)}
					<EventCardCompact {event} />
				{/each}
			</div>
		</section>
	{/if}

	<!-- Activity feed -->
	<section class="space-y-4" aria-busy={feed.loading || feed.loadingMore}>
		<h3 class="font-headline text-lg font-bold">{m('social.home.feedTitle')}</h3>

		{#if feed.loading && !feed.loaded}
			<PostCardSkeleton count={2} />
		{:else if feed.error && !feed.loaded}
			<div class="space-y-3 rounded-2xl bg-surface-container-low py-12 text-center">
				<span class="material-symbols-outlined text-4xl text-error">warning</span>
				<p class="font-semibold text-on-surface">{m('social.feed.errorTitle')}</p>
				<button
					type="button"
					onclick={() => pager?.refresh()}
					class="rounded-full bg-surface-container-high px-5 py-2 text-sm font-bold text-on-surface transition-all hover:scale-105 active:scale-95"
				>
					{m('common.retry')}
				</button>
			</div>
		{:else if feed.items.length === 0}
			<div class="space-y-3 rounded-2xl bg-surface-container-low px-6 py-12 text-center">
				{#if emptyKind === 'noFriends'}
					<div class="flex justify-center gap-1 text-primary">
						<span class="material-symbols-outlined text-5xl">chess_pawn</span>
						<span class="material-symbols-outlined -rotate-12 text-5xl text-tertiary"
							>waving_hand</span
						>
					</div>
					<p class="font-headline text-lg font-bold text-on-surface">
						{m('social.feed.emptyNoFriendsTitle')}
					</p>
					<p class="text-sm text-on-surface-variant">{m('social.feed.emptyNoFriendsBody')}</p>
					<a
						href="/onboarding/find-friends"
						class="inline-block rounded-full bg-gradient-to-r from-primary to-primary-container px-6 py-2.5 font-headline text-sm font-bold text-on-primary shadow-[0_8px_24px_rgba(137,81,0,0.20)] transition-all hover:scale-105 active:scale-95"
					>
						{m('social.feed.findFriends')}
					</a>
				{:else}
					<span class="material-symbols-outlined text-5xl text-on-surface-variant/40">
						{emptyKind === 'pending' ? 'hourglass_top' : 'feed'}
					</span>
					<p class="font-headline text-lg font-bold text-on-surface">
						{m(
							emptyKind === 'pending'
								? 'social.feed.emptyPendingTitle'
								: 'social.feed.emptyQuietTitle'
						)}
					</p>
					<p class="text-sm text-on-surface-variant">
						{m(
							emptyKind === 'pending'
								? 'social.feed.emptyPendingBody'
								: 'social.feed.emptyQuietBody'
						)}
					</p>
					<a
						href="/posts/create"
						class="inline-block rounded-full bg-gradient-to-r from-primary to-primary-container px-6 py-2.5 font-headline text-sm font-bold text-on-primary shadow-[0_8px_24px_rgba(137,81,0,0.20)] transition-all hover:scale-105 active:scale-95"
					>
						{m('social.feed.createPost')}
					</a>
				{/if}
			</div>
		{:else}
			<div class="space-y-4">
				{#each feed.items as item (itemKey(item))}
					{#if item.kind === 'post'}
						<PostCard bind:post={item.post} onDeleted={removePost} />
					{:else}
						<ActivityItem activity={item.activity} createdAt={item.createdAt} />
					{/if}
				{/each}
			</div>

			<div class="py-4 text-center text-sm text-on-surface-variant" aria-live="polite">
				{#if feed.loadingMore}
					<span class="inline-flex items-center gap-2"
						><Spinner className="h-4 w-4" />{m('social.feed.loadingMore')}</span
					>
				{:else if feed.error}
					<p>{m('social.feed.loadMoreFailed')}</p>
					<button
						type="button"
						onclick={() => pager?.loadMore()}
						class="mt-1 font-bold text-primary"
					>
						{m('common.retry')}
					</button>
				{:else if !feed.hasMore}
					<p class="font-semibold">{m('social.feed.caughtUp')}</p>
				{/if}
			</div>
		{/if}
	</section>
</div>
