<script lang="ts">
	import { onMount, untrack } from 'svelte';
	import type { CursorPage, Post } from '$lib/types';
	import { m } from '$lib/i18n';
	import PostCard from './PostCard.svelte';
	import PostCardSkeleton from './PostCardSkeleton.svelte';
	import Spinner from '$lib/components/ui/Spinner.svelte';
	import { CursorPager, preferExisting, watchScrollDepth, type PagerState } from './cursorPager';

	/**
	 * Infinite list of posts from any cursor endpoint (saved posts, event memories). Loads the next
	 * page at 80% scroll depth and shows loading, error and end states.
	 */
	interface Props {
		fetchPage: (cursor: string | null) => Promise<CursorPage<Post>>;
		emptyText: string;
		/** Remove a post from the list when this returns true for an updated post (e.g. un-bookmarked). */
		dropWhen?: (post: Post) => boolean;
	}
	let { fetchPage, emptyText, dropWhen }: Props = $props();

	const key = (p: Post) => p.id;
	let list = $state<PagerState<Post>>({
		items: [],
		loading: true,
		loadingMore: false,
		hasMore: true,
		error: null,
		loaded: false
	});
	let pager: CursorPager<Post> | null = null;

	// A fresh pager per source; the previous one is retired on teardown and its late pages are
	// ignored, so it never writes over the new list.
	$effect(() => {
		const fetcher = fetchPage;
		let alive = true;
		const p = untrack(() => {
			list = { ...list, items: [] };
			const next = new CursorPager<Post>(fetcher, key, (state) => {
				if (!alive) return;
				list = { ...state, items: preferExisting(list.items, state.items, key) };
			});
			pager = next;
			void next.loadMore();
			return next;
		});
		return () => {
			alive = false;
			p.dispose();
		};
	});

	onMount(() =>
		watchScrollDepth(() => {
			if (pager && list.loaded && list.hasMore && !list.loadingMore && !list.error)
				void pager.loadMore();
		})
	);

	const visible = $derived(dropWhen ? list.items.filter((p) => !dropWhen(p)) : list.items);

	function remove(postId: string) {
		pager?.update((items) => items.filter((p) => p.id !== postId));
	}
</script>

{#if list.loading && !list.loaded}
	<PostCardSkeleton count={2} />
{:else if list.error && !list.loaded}
	<div class="space-y-3 rounded-2xl bg-surface-container-low py-12 text-center">
		<p class="font-semibold text-on-surface">{m('social.feed.loadMoreFailed')}</p>
		<button type="button" onclick={() => pager?.refresh()} class="text-sm font-bold text-primary"
			>{m('common.retry')}</button
		>
	</div>
{:else if visible.length === 0}
	<p
		class="rounded-2xl bg-surface-container-low px-6 py-12 text-center text-sm text-on-surface-variant"
	>
		{emptyText}
	</p>
{:else}
	<div class="space-y-4">
		{#each list.items as post, i (post.id)}
			{#if !dropWhen || !dropWhen(post)}
				<PostCard bind:post={list.items[i]} onDeleted={remove} />
			{/if}
		{/each}
	</div>
	<div class="py-4 text-center text-sm text-on-surface-variant" aria-live="polite">
		{#if list.loadingMore}
			<span class="inline-flex items-center gap-2"
				><Spinner className="h-4 w-4" />{m('social.feed.loadingMore')}</span
			>
		{:else if list.error}
			<button type="button" onclick={() => pager?.loadMore()} class="font-bold text-primary"
				>{m('common.retry')}</button
			>
		{:else if !list.hasMore}
			<p class="font-semibold">{m('social.feed.caughtUp')}</p>
		{/if}
	</div>
{/if}
