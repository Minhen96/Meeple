// Home feed: after a reload (new page data) the previous CursorPager's late page must not
// replace the refreshed feed.
import { render, screen, waitFor, within } from '@testing-library/svelte';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { m } from '$lib/i18n';
import type { CursorPage, FeedItem, Post } from '$lib/types';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({
	getFeedPage: vi.fn(),
	friends: { getReceived: vi.fn(), suggestFriends: vi.fn() }
}));
vi.mock('svelte-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/posts', () => ({ postsApi: { getFeedPage: h.getFeedPage } }));
vi.mock('$lib/api/friends', () => ({ friendsApi: h.friends }));

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

describe('home right rail', () => {
	const page = { items: [postItem('x')], nextCursor: null, hasMore: false };
	const event = {
		id: 'e1',
		title: 'Catan Night',
		scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
		participants: [],
		participantCount: 1,
		maxParticipants: 4,
		location: null
	};
	const withEvents = () => ({ ...(data(page) as object), upcomingEvents: [event] }) as never;

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('puts upcoming events in the rail and loads friend widgets only at xl', async () => {
		h.friends.getReceived.mockResolvedValue({ data: [], meta: { total: 0 } });
		h.friends.suggestFriends.mockResolvedValue([]);
		const { unmount } = render(Page, { data: withEvents() });
		const rail = screen.getByRole('complementary', { name: m('social.home.railLabel') });
		expect(within(rail).getByText('Catan Night')).toBeInTheDocument();
		expect(h.friends.getReceived).not.toHaveBeenCalled();
		unmount();

		vi.stubGlobal(
			'matchMedia',
			vi.fn((query: string) => ({
				matches: true,
				media: query,
				addEventListener: vi.fn(),
				removeEventListener: vi.fn()
			}))
		);
		render(Page, { data: withEvents() });
		await waitFor(() => expect(h.friends.getReceived).toHaveBeenCalled());
		expect(h.friends.suggestFriends).toHaveBeenCalled();
	});
});
