// Page load functions under (app): data assembly, per-section degradation and error mapping.
import { isHttpError, isRedirect } from '@sveltejs/kit';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiRequestError } from '$lib/api/client';
import { throwLoadError } from '$lib/api/load';

const apis = vi.hoisted(() => ({
	posts: {
		getFeedPage: vi.fn(),
		getUserPosts: vi.fn(),
		getTaggedPosts: vi.fn(),
		getPost: vi.fn(),
		getComments: vi.fn()
	},
	events: { getMyEvents: vi.fn(), getCommunity: vi.fn(), list: vi.fn(), getEvent: vi.fn() },
	matches: { getSuggestions: vi.fn() },
	friends: { getFriends: vi.fn(), getSent: vi.fn(), getStatus: vi.fn() },
	games: { getMyCollection: vi.fn(), getGame: vi.fn(), getUserCollection: vi.fn() },
	users: { getStats: vi.fn(), getUser: vi.fn() }
}));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/posts', () => ({ postsApi: apis.posts }));
vi.mock('$lib/api/events', () => ({ eventsApi: apis.events }));
vi.mock('$lib/api/matches', () => ({ matchesApi: apis.matches }));
vi.mock('$lib/api/friends', () => ({ friendsApi: apis.friends }));
vi.mock('$lib/api/games', () => ({ gamesApi: apis.games }));
vi.mock('$lib/api/users', () => ({ usersApi: apis.users }));

const home = await import('./+page');
const events = await import('./events/+page');
const eventDetail = await import('./events/[eventId]/+page');
const eventEdit = await import('./events/[eventId]/edit/+page');
const library = await import('./library/+page');
const game = await import('./library/[gameId]/+page');
const post = await import('./posts/[postId]/+page');
const profile = await import('./profile/+page');
const otherProfile = await import('./profile/[userId]/+page');
const friends = await import('./profile/friends/+page');
const changeEmail = await import('./settings/change-email/+page');
const deleteAccount = await import('./settings/delete-account/+page');
const password = await import('./settings/password/+page');
const settingsProfile = await import('./settings/profile/+page');

const ME = { id: 'me', username: 'me', onboardingCompleted: true };
const fetchFn = vi.fn() as unknown as typeof fetch;

type AnyLoad = (event: never) => unknown;

/** Run a PageLoad with a minimal event; returns the data or the thrown redirect/error. */
async function run(
	load: AnyLoad,
	{ path = '/', params = {}, user = ME as unknown }: { path?: string; params?: Record<string, string>; user?: unknown } = {}
) {
	const event = {
		parent: async () => ({ user }),
		fetch: fetchFn,
		url: new URL(`http://app.test${path}`),
		params
	} as never;
	try {
		return { data: (await load(event)) as Record<string, unknown>, thrown: null as unknown };
	} catch (err) {
		return { data: null, thrown: err };
	}
}

const apiError = (status: number) => new ApiRequestError('X', 'x', status);
const page = <T>(items: T[], total = items.length) => ({ data: items, meta: { total } });

beforeEach(() => {
	for (const group of Object.values(apis)) for (const fn of Object.values(group)) fn.mockReset();
});

describe('throwLoadError', () => {
	const url = new URL('http://app.test/events/e 1');
	const thrownBy = (err: unknown) => {
		try {
			throwLoadError(err, url, 'Nope');
		} catch (e) {
			return e;
		}
	};

	it('401 redirects to login with the encoded path', () => {
		const e = thrownBy(apiError(401));
		expect(isRedirect(e)).toBe(true);
		expect(e).toMatchObject({ status: 303, location: '/auth/login?redirect=%2Fevents%2Fe%25201' });
	});

	it.each([403, 404, 410])('%i becomes a 404 with the not-found message', (status) => {
		const e = thrownBy(apiError(status));
		expect(isHttpError(e)).toBe(true);
		expect(e).toMatchObject({ status: 404, body: { message: 'Nope' } });
	});

	it.each([apiError(500), apiError(0), new Error('boom'), 'weird'])('anything else is a 500 (%s)', (err) => {
		const e = thrownBy(err);
		expect(isHttpError(e)).toBe(true);
		expect(e).toMatchObject({ status: 500 });
	});

	it('uses a default not-found message', () => {
		try {
			throwLoadError(apiError(404), url);
		} catch (e) {
			expect(e).toMatchObject({ body: { message: 'Not found' } });
		}
	});
});

describe('home feed load', () => {
	it('keeps only upcoming, non-cancelled events sorted soonest first, and counts friends', async () => {
		const future = (days: number) => new Date(Date.now() + days * 86400000).toISOString();
		apis.posts.getFeedPage.mockResolvedValue({ items: [], nextCursor: null, hasMore: false });
		apis.events.getMyEvents.mockResolvedValue([
			{ id: 'later', scheduledAt: future(5), status: 'SCHEDULED' },
			{ id: 'past', scheduledAt: future(-1), status: 'SCHEDULED' },
			{ id: 'cancelled', scheduledAt: future(1), status: 'CANCELLED' },
			{ id: 'soon', scheduledAt: future(2), status: 'SCHEDULED' }
		]);
		apis.matches.getSuggestions.mockResolvedValue([{ id: 'm' }]);
		apis.friends.getFriends.mockResolvedValue(page([], 7));
		apis.friends.getSent.mockResolvedValue(page([], 2));

		const { data } = await run(home.load);
		expect(data?.upcomingEvents).toEqual([
			expect.objectContaining({ id: 'soon' }),
			expect.objectContaining({ id: 'later' })
		]);
		expect(data).toMatchObject({ user: ME, friendCount: 7, pendingSentCount: 2, matchSuggestions: [{ id: 'm' }] });
		expect(apis.posts.getFeedPage).toHaveBeenCalledWith(null, 20, { fetch: fetchFn });
	});

	it('degrades every section independently when the APIs fail', async () => {
		for (const fn of [
			apis.posts.getFeedPage,
			apis.events.getMyEvents,
			apis.matches.getSuggestions,
			apis.friends.getFriends,
			apis.friends.getSent
		])
			fn.mockRejectedValue(apiError(500));
		const { data } = await run(home.load);
		expect(data).toEqual({
			user: ME,
			feed: null,
			upcomingEvents: [],
			matchSuggestions: [],
			friendCount: 0,
			pendingSentCount: 0
		});
	});
});

describe('events list load', () => {
	it('loads the community tab via the cursor API and exposes nextCursor only when hasMore', async () => {
		apis.events.getCommunity.mockResolvedValue({ items: [{ id: 'e' }], nextCursor: 'c2', hasMore: true });
		const { data } = await run(events.load, { path: '/events?tab=community' });
		expect(data).toMatchObject({ tab: 'community', view: 'list', events: [{ id: 'e' }], nextCursor: 'c2', loadFailed: false });

		apis.events.getCommunity.mockResolvedValue({ items: [], nextCursor: 'stale', hasMore: false });
		expect((await run(events.load, { path: '/events?tab=community' })).data?.nextCursor).toBeNull();
	});

	it('loads upcoming/past via list()', async () => {
		apis.events.list.mockResolvedValue([{ id: 'p' }]);
		const { data } = await run(events.load, { path: '/events?tab=past' });
		expect(apis.events.list).toHaveBeenCalledWith('past', 50, { fetch: fetchFn });
		expect(data).toMatchObject({ tab: 'past', events: [{ id: 'p' }] });
	});

	it('flags loadFailed instead of throwing', async () => {
		apis.events.list.mockRejectedValue(apiError(500));
		const { data } = await run(events.load, { path: '/events' });
		expect(data).toMatchObject({ events: [], loadFailed: true });
	});

	it('skips the list in calendar view', async () => {
		const { data } = await run(events.load, { path: '/events?view=calendar' });
		expect(data).toMatchObject({ view: 'calendar', events: [] });
		expect(apis.events.list).not.toHaveBeenCalled();
	});
});

describe.each([
	['event detail', eventDetail.load, true],
	['event edit', eventEdit.load, false]
] as const)('%s load', (_name, load, includesUser) => {
	it('returns the event', async () => {
		apis.events.getEvent.mockResolvedValue({ id: 'e1' });
		const { data } = await run(load, { params: { eventId: 'e1' } });
		expect(data?.event).toEqual({ id: 'e1' });
		expect('user' in (data ?? {})).toBe(includesUser);
		expect(apis.events.getEvent).toHaveBeenCalledWith('e1', { fetch: fetchFn });
	});

	it('maps a 404 to "Event not found"', async () => {
		apis.events.getEvent.mockRejectedValue(apiError(404));
		const { thrown } = await run(load, { params: { eventId: 'e1' } });
		expect(thrown).toMatchObject({ status: 404, body: { message: 'Event not found' } });
	});
});

describe('library loads', () => {
	it('library list falls back to an empty collection', async () => {
		apis.games.getMyCollection.mockRejectedValue(apiError(500));
		expect((await run(library.load)).data).toEqual({ user: ME, collection: [] });
	});

	it('game detail finds my collection entry for the game', async () => {
		apis.games.getGame.mockResolvedValue({ id: 'g1' });
		apis.games.getMyCollection.mockResolvedValue([{ game: { id: 'g0' } }, { game: { id: 'g1' }, isOwned: true }]);
		const { data } = await run(game.load, { params: { gameId: 'g1' } });
		expect(data).toMatchObject({ game: { id: 'g1' }, myEntry: { isOwned: true } });
	});

	it('game detail: no entry when the collection fails; 404 when the game is missing', async () => {
		apis.games.getGame.mockResolvedValue({ id: 'g1' });
		apis.games.getMyCollection.mockRejectedValue(apiError(500));
		expect((await run(game.load, { params: { gameId: 'g1' } })).data?.myEntry).toBeNull();

		apis.games.getGame.mockRejectedValue(apiError(404));
		const { thrown } = await run(game.load, { params: { gameId: 'g1' } });
		expect(thrown).toMatchObject({ status: 404, body: { message: 'Game not found' } });
	});
});

describe('post detail load', () => {
	const commentPage = (items: unknown[], nextCursor: string | null) => ({ items, nextCursor, hasMore: nextCursor !== null });

	it('returns post + first comment page with its cursor, and reads ?edit=1', async () => {
		apis.posts.getPost.mockResolvedValue({ id: 'p1' });
		apis.posts.getComments.mockResolvedValue(commentPage([{ id: 'c1' }], 'c2'));
		const { data } = await run(post.load, { path: '/posts/p1?edit=1', params: { postId: 'p1' } });
		expect(data).toMatchObject({ post: { id: 'p1' }, comments: [{ id: 'c1' }], commentsCursor: 'c2', editRequested: true });
		expect(apis.posts.getComments).toHaveBeenCalledWith('p1', null, 20, { fetch: fetchFn });
	});

	it('no cursor when there are no more comments', async () => {
		apis.posts.getPost.mockResolvedValue({ id: 'p1' });
		apis.posts.getComments.mockResolvedValue({ items: [], nextCursor: 'stale', hasMore: false });
		const { data } = await run(post.load, { params: { postId: 'p1' } });
		expect(data?.commentsCursor).toBeNull();
	});

	it('comments failing still renders the post', async () => {
		apis.posts.getPost.mockResolvedValue({ id: 'p1' });
		apis.posts.getComments.mockRejectedValue(apiError(500));
		const { data } = await run(post.load, { params: { postId: 'p1' } });
		expect(data).toMatchObject({ comments: [], commentsCursor: null, editRequested: false });
	});

	it('a 404 renders the "removed" state instead of an error page', async () => {
		apis.posts.getPost.mockRejectedValue(apiError(404));
		apis.posts.getComments.mockResolvedValue(commentPage([], null));
		const { data } = await run(post.load, { path: '/posts/p1?edit=1', params: { postId: 'p1' } });
		expect(data).toEqual({ user: ME, post: null, comments: [], commentsCursor: null, editRequested: false });
	});

	it('other errors go through throwLoadError', async () => {
		apis.posts.getPost.mockRejectedValue(apiError(401));
		apis.posts.getComments.mockResolvedValue(commentPage([], null));
		const { thrown } = await run(post.load, { path: '/posts/p1', params: { postId: 'p1' } });
		expect(isRedirect(thrown)).toBe(true);
	});
});

describe('my profile load', () => {
	it('redirects when there is no user', async () => {
		const { thrown } = await run(profile.load, { user: null });
		expect(thrown).toMatchObject({ status: 303, location: '/auth/login' });
	});

	it('assembles every section', async () => {
		apis.posts.getUserPosts.mockResolvedValue([{ id: 'p' }]);
		apis.posts.getTaggedPosts.mockResolvedValue({ items: [{ id: 't' }], nextCursor: null, hasMore: false });
		apis.games.getMyCollection.mockResolvedValue([{ id: 'ug' }]);
		apis.friends.getFriends.mockResolvedValue(page([], 3));
		apis.users.getStats.mockResolvedValue({ gamesOwned: 1 });
		const { data } = await run(profile.load);
		expect(data).toEqual({
			user: ME,
			posts: [{ id: 'p' }],
			taggedPosts: [{ id: 't' }],
			collection: [{ id: 'ug' }],
			friendCount: 3,
			stats: { gamesOwned: 1 }
		});
		expect(apis.posts.getUserPosts).toHaveBeenCalledWith('me', 0, 30, { fetch: fetchFn });
	});

	it('each failing section degrades on its own', async () => {
		for (const fn of [
			apis.posts.getUserPosts,
			apis.posts.getTaggedPosts,
			apis.games.getMyCollection,
			apis.friends.getFriends,
			apis.users.getStats
		])
			fn.mockRejectedValue(apiError(500));
		const { data } = await run(profile.load);
		expect(data).toEqual({ user: ME, posts: [], taggedPosts: null, collection: [], friendCount: null, stats: null });
	});
});

describe('other user profile load', () => {
	const ok = (status: string) => {
		apis.users.getUser.mockResolvedValue({ id: 'u2' });
		apis.friends.getStatus.mockResolvedValue({ status });
		apis.posts.getUserPosts.mockResolvedValue([]);
		apis.posts.getTaggedPosts.mockResolvedValue({ items: [], nextCursor: null, hasMore: false });
		apis.games.getUserCollection.mockResolvedValue([{ id: 'ug' }]);
		apis.users.getStats.mockResolvedValue(null);
	};

	it('redirects to /profile for my own id', async () => {
		const { thrown } = await run(otherProfile.load, { params: { userId: 'me' } });
		expect(thrown).toMatchObject({ status: 302, location: '/profile' });
	});

	it("shows a friend's collection", async () => {
		ok('FRIENDS');
		const { data } = await run(otherProfile.load, { params: { userId: 'u2' } });
		expect(data).toMatchObject({ user: { id: 'u2' }, isFriend: true, collection: [{ id: 'ug' }] });
		expect(apis.games.getUserCollection).toHaveBeenCalledWith('u2', { fetch: fetchFn });
	});

	it("does not request a non-friend's collection", async () => {
		ok('NONE');
		const { data } = await run(otherProfile.load, { params: { userId: 'u2' }, user: null });
		expect(data).toMatchObject({ isFriend: false, collection: [] });
		expect(apis.games.getUserCollection).not.toHaveBeenCalled();
	});

	it('degrades sections for a friend whose lists fail', async () => {
		ok('FRIENDS');
		apis.posts.getUserPosts.mockRejectedValue(apiError(500));
		apis.posts.getTaggedPosts.mockRejectedValue(apiError(403));
		apis.games.getUserCollection.mockRejectedValue(apiError(500));
		apis.users.getStats.mockRejectedValue(apiError(404));
		const { data } = await run(otherProfile.load, { params: { userId: 'u2' } });
		expect(data).toMatchObject({ posts: [], taggedPosts: null, collection: [], stats: null });
	});

	it('404s for blocked / missing users', async () => {
		apis.users.getUser.mockRejectedValue(apiError(404));
		apis.friends.getStatus.mockResolvedValue({ status: 'NONE' });
		const { thrown } = await run(otherProfile.load, { params: { userId: 'u2' } });
		expect(thrown).toMatchObject({ status: 404, body: { message: 'User not found' } });
	});
});

describe('friends list load', () => {
	it('returns the first page', async () => {
		apis.friends.getFriends.mockResolvedValue(page([{ id: 'f' }], 1));
		const { data } = await run(friends.load);
		expect(data).toEqual({ friends: [{ id: 'f' }], meta: { total: 1 } });
		expect(apis.friends.getFriends).toHaveBeenCalledWith(0, 20, { fetch: fetchFn });
	});

	it('maps errors', async () => {
		apis.friends.getFriends.mockRejectedValue(apiError(500));
		expect((await run(friends.load)).thrown).toMatchObject({ status: 500 });
	});
});

describe.each([
	['change-email', changeEmail.load],
	['delete-account', deleteAccount.load],
	['password', password.load],
	['settings profile', settingsProfile.load]
] as const)('%s settings load', (_n, load) => {
	it('passes the parent user through', async () => {
		expect((await run(load)).data).toEqual({ user: ME });
	});
});
