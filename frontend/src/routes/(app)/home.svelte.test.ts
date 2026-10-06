// Home feed: after a reload (new page data) the previous CursorPager's late page must not
// replace the refreshed feed.
import { render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import type { CursorPage, FeedItem, Post } from '$lib/types';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({ getFeedPage: vi.fn() }));
vi.mock('svelte-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/posts', () => ({ postsApi: { getFeedPage: h.getFeedPage } }));

function postItem(id: string): FeedItem {
	const post: Post = {
		id,
		author: { id: 'a', username: 'ann', displayName: 'Ann', avatarUrl: null, deleted: false },
		caption: `CAPTION_${id}`,
		location: null,
		playedAt: null,
		imageUrls: [],
		game: null,
		eventId: null,
		taggedUsers: [],
		likeCount: 0,
		commentCount: 0,
		likedByMe: false,
		isBookmarked: false,
		createdAt: new Date().toISOString(),
		editedAt: null
	};
	return { kind: 'post', post, createdAt: post.createdAt } as FeedItem;
}

const data = (feed: CursorPage<FeedItem> | null) =>
	({
		user: null,
		feed,
		upcomingEvents: [],
		matchSuggestions: [],
		friendCount: 1,
		pendingSentCount: 0
	}) as never;

describe('home feed', () => {
	it('ignores the replaced pager when its page arrives after a reload', async () => {
		let resolveOld: (page: CursorPage<FeedItem>) => void = () => {};
		h.getFeedPage.mockReturnValueOnce(new Promise((r) => (resolveOld = r)));

		const { rerender } = render(Page, { data: data(null) });
		expect(h.getFeedPage).toHaveBeenCalledWith(null, 20);

		await rerender({ data: data({ items: [postItem('fresh')], nextCursor: null, hasMore: false }) });
		await waitFor(() => expect(screen.getByText('CAPTION_fresh')).toBeInTheDocument());

		resolveOld({ items: [postItem('stale')], nextCursor: null, hasMore: false });
		await new Promise((r) => setTimeout(r, 0));

		expect(screen.queryByText('CAPTION_stale')).toBeNull();
		expect(screen.getByText('CAPTION_fresh')).toBeInTheDocument();
	});
});
