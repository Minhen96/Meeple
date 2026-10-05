// Endpoint contract tests for every API module: each call must hit the right
// method + URL with the right body, and map responses/errors as documented.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { API_BASE, callAt, installFetch, jsonResponse, lastCall, type FetchMock } from '../../test/fetch';

vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.stubEnv('VITE_API_URL', API_BASE);

const { ApiRequestError, __resetRefreshStateForTests } = await import('./client');
const { adminApi } = await import('./admin');
const { aiApi } = await import('./ai');
const { authApi } = await import('./auth');
const { eventsApi } = await import('./events');
const { friendsApi, searchApi, reportsApi } = await import('./friends');
const { gamesApi } = await import('./games');
const { howToPlayApi } = await import('./howtoplay');
const { matchesApi } = await import('./matches');
const { postsApi } = await import('./posts');
const { ruleNotesApi } = await import('./ruleNotes');
const { rulebookApi } = await import('./rulebook');
const { setupApi } = await import('./setup');
const { uploadApi, MAX_PRESIGNED_UPLOAD_BYTES } = await import('./upload');
const { usersApi, usernameProblem, displayNameOf, PROFILE_LIMITS } = await import('./users');

let fetchMock: FetchMock;

beforeEach(() => {
	__resetRefreshStateForTests();
	fetchMock = installFetch();
});

afterEach(() => {
	vi.unstubAllGlobals();
});

type Case = [name: string, call: () => Promise<unknown>, method: string, path: string, body?: unknown];

const file = new File(['abc'], 'a.png', { type: 'image/png' });

const cases: Case[] = [
	// admin
	['admin.getRulebookQueue default', () => adminApi.getRulebookQueue(), 'GET', '/api/v1/admin/rulebooks?status=pending_review&page=0&size=20'],
	['admin.getRulebookQueue custom', () => adminApi.getRulebookQueue('failed', 2, 5), 'GET', '/api/v1/admin/rulebooks?status=failed&page=2&size=5'],
	['admin.approveRulebook', () => adminApi.approveRulebook('r1'), 'POST', '/api/v1/admin/rulebooks/r1/approve'],
	['admin.retryRulebook', () => adminApi.retryRulebook('r1'), 'POST', '/api/v1/admin/rulebooks/r1/retry'],
	['admin.rejectRulebook', () => adminApi.rejectRulebook('r1', 'spam'), 'POST', '/api/v1/admin/rulebooks/r1/reject', { reason: 'spam' }],
	['admin.getRuleNoteQueue', () => adminApi.getRuleNoteQueue(), 'GET', '/api/v1/admin/rule-notes?page=0&size=20'],
	['admin.approveRuleNote', () => adminApi.approveRuleNote('n1'), 'POST', '/api/v1/admin/rule-notes/n1/approve'],
	['admin.rejectRuleNote', () => adminApi.rejectRuleNote('n1', 'bad'), 'POST', '/api/v1/admin/rule-notes/n1/reject', { reason: 'bad' }],
	['admin.promoteUser', () => adminApi.promoteUser('u1'), 'POST', '/api/v1/admin/users/u1/promote'],
	// ai
	['ai.askRules default history', () => aiApi.askRules('g1', 'How?'), 'POST', '/api/v1/ai/rules', { gameId: 'g1', question: 'How?', conversationHistory: [] }],
	// auth
	['auth.login', () => authApi.login('bob', 'pw'), 'POST', '/api/v1/auth/login', { emailOrUsername: 'bob', password: 'pw' }],
	['auth.register', () => authApi.register('a@b.c', 'bob', 'pw'), 'POST', '/api/v1/auth/register', { email: 'a@b.c', username: 'bob', password: 'pw' }],
	['auth.logout', () => authApi.logout(), 'POST', '/api/v1/auth/logout'],
	['auth.refresh', () => authApi.refresh(), 'POST', '/api/v1/auth/refresh'],
	['auth.googleLogin', () => authApi.googleLogin('tok'), 'POST', '/api/v1/auth/google', { idToken: 'tok' }],
	['auth.reactivate', () => authApi.reactivate({ googleIdToken: 't' }), 'POST', '/api/v1/auth/reactivate', { googleIdToken: 't' }],
	['auth.verifyEmail', () => authApi.verifyEmail('t'), 'POST', '/api/v1/auth/verify-email', { token: 't' }],
	['auth.resendVerification', () => authApi.resendVerification('a@b.c'), 'POST', '/api/v1/auth/resend-verification', { email: 'a@b.c' }],
	['auth.forgotPassword', () => authApi.forgotPassword('a@b.c'), 'POST', '/api/v1/auth/forgot-password', { email: 'a@b.c' }],
	['auth.resetPassword', () => authApi.resetPassword('t', 'new'), 'POST', '/api/v1/auth/reset-password', { token: 't', newPassword: 'new' }],
	['auth.confirmEmailChange', () => authApi.confirmEmailChange('t'), 'POST', '/api/v1/auth/confirm-email-change', { token: 't' }],
	['auth.sessions', () => authApi.sessions(), 'GET', '/api/v1/auth/sessions'],
	['auth.revokeSession encodes id', () => authApi.revokeSession('a/b'), 'DELETE', '/api/v1/auth/sessions/a%2Fb'],
	['auth.revokeOtherSessions', () => authApi.revokeOtherSessions(), 'POST', '/api/v1/auth/sessions/revoke-others'],
	// events
	['events.getUpcoming', () => eventsApi.getUpcoming(), 'GET', '/api/v1/events?scope=upcoming&limit=50'],
	['events.list', () => eventsApi.list('past', 10), 'GET', '/api/v1/events?scope=past&limit=10'],
	['events.getMyEvents', () => eventsApi.getMyEvents(), 'GET', '/api/v1/events/me'],
	[
		'events.getCalendar encodes ISO range',
		() => eventsApi.getCalendar(new Date('2026-01-01T00:00:00Z'), new Date('2026-02-01T00:00:00Z')),
		'GET',
		'/api/v1/events/calendar?from=2026-01-01T00%3A00%3A00.000Z&to=2026-02-01T00%3A00%3A00.000Z'
	],
	['events.getCommunity defaults', () => eventsApi.getCommunity(), 'GET', '/api/v1/events/community?limit=20'],
	['events.getCommunity with cursor', () => eventsApi.getCommunity({ gameId: 'g1', cursor: 'c 1', limit: 5 }), 'GET', '/api/v1/events/community?gameId=g1&cursor=c+1&limit=5'],
	['events.getEvent', () => eventsApi.getEvent('e1'), 'GET', '/api/v1/events/e1'],
	['events.createEvent', () => eventsApi.createEvent({ title: 'T', scheduledAt: 'x', visibility: 'PUBLIC' }), 'POST', '/api/v1/events', { title: 'T', scheduledAt: 'x', visibility: 'PUBLIC' }],
	['events.updateEvent', () => eventsApi.updateEvent('e1', { title: 'U' }), 'PUT', '/api/v1/events/e1', { title: 'U' }],
	['events.cancelEvent', () => eventsApi.cancelEvent('e1'), 'POST', '/api/v1/events/e1/cancel'],
	['events.deleteEvent', () => eventsApi.deleteEvent('e1'), 'DELETE', '/api/v1/events/e1'],
	['events.invite', () => eventsApi.invite('e1', ['u1', 'u2']), 'POST', '/api/v1/events/e1/invites', { userIds: ['u1', 'u2'] }],
	['events.rsvp', () => eventsApi.rsvp('e1', 'ACCEPTED'), 'POST', '/api/v1/events/e1/rsvp?status=ACCEPTED'],
	['events.leaveEvent', () => eventsApi.leaveEvent('e1'), 'DELETE', '/api/v1/events/e1/rsvp'],
	['events.kick', () => eventsApi.kick('e1', 'u1'), 'DELETE', '/api/v1/events/e1/participants/u1'],
	['events.getMemories first page', () => eventsApi.getMemories('e1'), 'GET', '/api/v1/posts?eventId=e1'],
	['events.getMemories cursor', () => eventsApi.getMemories('e1', 'a&b'), 'GET', '/api/v1/posts?eventId=e1&cursor=a%26b'],
	// friends / search / reports
	['friends.sendRequest', () => friendsApi.sendRequest('u1'), 'POST', '/api/v1/users/u1/friend-request', {}],
	['friends.cancelTo', () => friendsApi.cancelTo('u1'), 'DELETE', '/api/v1/users/u1/friend-request'],
	['friends.getStatus', () => friendsApi.getStatus('u1'), 'GET', '/api/v1/users/u1/friend-status'],
	['friends.accept', () => friendsApi.accept('r1'), 'POST', '/api/v1/friend-requests/r1/accept', {}],
	['friends.decline', () => friendsApi.decline('r1'), 'POST', '/api/v1/friend-requests/r1/decline', {}],
	['friends.cancel', () => friendsApi.cancel('r1'), 'DELETE', '/api/v1/friend-requests/r1'],
	['friends.unfriend', () => friendsApi.unfriend('u1'), 'DELETE', '/api/v1/friends/u1'],
	['friends.getFriends', () => friendsApi.getFriends(), 'GET', '/api/v1/friends?page=0&size=20'],
	['friends.getReceived', () => friendsApi.getReceived(1, 5), 'GET', '/api/v1/friend-requests/received?page=1&size=5'],
	['friends.getSent', () => friendsApi.getSent(), 'GET', '/api/v1/friend-requests/sent?page=0&size=20'],
	['friends.blockUser', () => friendsApi.blockUser('u1'), 'POST', '/api/v1/users/u1/block', {}],
	['friends.unblockUser', () => friendsApi.unblockUser('u1'), 'DELETE', '/api/v1/users/u1/block'],
	['friends.getBlocked', () => friendsApi.getBlocked(), 'GET', '/api/v1/users/me/blocked'],
	['friends.suggestFriends', () => friendsApi.suggestFriends(), 'GET', '/api/v1/friends/suggestions?limit=10'],
	['search.search defaults', () => searchApi.search('cat'), 'GET', '/api/v1/search?q=cat&limit=3&type=all'],
	['search.search typed', () => searchApi.search('cat', { type: 'games', limit: 9 }), 'GET', '/api/v1/search?q=cat&limit=9&type=games'],
	['reports.report', () => reportsApi.report('post', 'p1', 'spam'), 'POST', '/api/v1/reports', { targetType: 'post', targetId: 'p1', reason: 'spam' }],
	// games
	['games.search', () => gamesApi.search('a&b'), 'GET', '/api/v1/games/search?q=a%26b'],
	['games.browse empty', () => gamesApi.browse({}), 'GET', '/api/v1/games?'],
	['games.getGame', () => gamesApi.getGame('g1'), 'GET', '/api/v1/games/g1'],
	['games.getMyCollection all', () => gamesApi.getMyCollection(), 'GET', '/api/v1/users/me/games'],
	['games.getMyCollection filtered', () => gamesApi.getMyCollection(undefined, 'owned'), 'GET', '/api/v1/users/me/games?filter=owned'],
	['games.updateCollection', () => gamesApi.updateCollection('g1', { isOwned: true }), 'PUT', '/api/v1/users/me/games/g1', { isOwned: true }],
	['games.removeFromCollection', () => gamesApi.removeFromCollection('g1'), 'DELETE', '/api/v1/users/me/games/g1'],
	['games.logPlay default', () => gamesApi.logPlay('g1'), 'POST', '/api/v1/users/me/games/g1/plays', {}],
	['games.deletePlay', () => gamesApi.deletePlay('p1'), 'DELETE', '/api/v1/users/me/plays/p1'],
	['games.getPlays', () => gamesApi.getPlays('g1'), 'GET', '/api/v1/users/me/games/g1/plays'],
	['games.getActivity', () => gamesApi.getActivity(), 'GET', '/api/v1/users/me/plays'],
	['games.ensureGame', () => gamesApi.ensureGame(13), 'GET', '/api/v1/games/bgg/13'],
	['games.getUserCollection', () => gamesApi.getUserCollection('u1'), 'GET', '/api/v1/users/u1/games'],
	['games.getUserActivity', () => gamesApi.getUserActivity('u1'), 'GET', '/api/v1/users/u1/plays'],
	['games.getUserStats', () => gamesApi.getUserStats('u1'), 'GET', '/api/v1/users/u1/stats'],
	['games.getGameFriends', () => gamesApi.getGameFriends('g1'), 'GET', '/api/v1/games/g1/friends'],
	['games.getGameReviews', () => gamesApi.getGameReviews('g1'), 'GET', '/api/v1/games/g1/reviews'],
	['games.getGameSessions first', () => gamesApi.getGameSessions('g1'), 'GET', '/api/v1/games/g1/sessions?limit=10'],
	['games.getGameSessions cursor', () => gamesApi.getGameSessions('g1', 'c1', 3), 'GET', '/api/v1/games/g1/sessions?limit=3&cursor=c1'],
	['games.startBggImport', () => gamesApi.startBggImport('bob'), 'POST', '/api/v1/users/me/bgg-import', { bggUsername: 'bob' }],
	['games.getBggImportStatus', () => gamesApi.getBggImportStatus(), 'GET', '/api/v1/users/me/bgg-import/status'],
	// how to play
	['howToPlay.get', () => howToPlayApi.get('g1'), 'GET', '/api/v1/games/g1/how-to-play'],
	['howToPlay.generate', () => howToPlayApi.generate('g1'), 'POST', '/api/v1/games/g1/how-to-play/generate'],
	// matches
	['matches.createRequest', () => matchesApi.createRequest({ gameId: 'g1' }), 'POST', '/api/v1/matches/requests', { gameId: 'g1' }],
	['matches.cancelRequest', () => matchesApi.cancelRequest('m1'), 'DELETE', '/api/v1/matches/requests/m1'],
	['matches.listMyRequests', () => matchesApi.listMyRequests(), 'GET', '/api/v1/matches/requests/me'],
	['matches.getSuggestions', () => matchesApi.getSuggestions(), 'GET', '/api/v1/matches/suggestions'],
	['matches.acceptMatch', () => matchesApi.acceptMatch('grp'), 'POST', '/api/v1/matches/grp/accept', {}],
	['matches.dismissMatch', () => matchesApi.dismissMatch('grp'), 'POST', '/api/v1/matches/grp/dismiss', {}],
	// posts
	['posts.getFeedPage first', () => postsApi.getFeedPage(), 'GET', '/api/v1/feed?limit=20'],
	['posts.getFeedPage cursor', () => postsApi.getFeedPage('abc', 5), 'GET', '/api/v1/feed?limit=5&cursor=abc'],
	['posts.getEventPosts', () => postsApi.getEventPosts('e1', 'c'), 'GET', '/api/v1/posts?limit=20&eventId=e1&cursor=c'],
	['posts.getTaggedPosts', () => postsApi.getTaggedPosts('u1'), 'GET', '/api/v1/users/u1/tagged-posts?limit=30'],
	['posts.getBookmarks', () => postsApi.getBookmarks(null, 7), 'GET', '/api/v1/users/me/bookmarks?limit=7'],
	['posts.getPost', () => postsApi.getPost('p1'), 'GET', '/api/v1/posts/p1'],
	['posts.createPost', () => postsApi.createPost({ caption: 'hi', imageKeys: ['k'] }), 'POST', '/api/v1/posts', { caption: 'hi', imageKeys: ['k'] }],
	['posts.updatePost', () => postsApi.updatePost('p1', { clearGame: true }), 'PUT', '/api/v1/posts/p1', { clearGame: true }],
	['posts.deletePost', () => postsApi.deletePost('p1'), 'DELETE', '/api/v1/posts/p1'],
	['posts.likePost', () => postsApi.likePost('p1'), 'POST', '/api/v1/posts/p1/like'],
	['posts.unlikePost', () => postsApi.unlikePost('p1'), 'DELETE', '/api/v1/posts/p1/like'],
	['posts.bookmarkPost', () => postsApi.bookmarkPost('p1'), 'POST', '/api/v1/posts/p1/bookmark'],
	['posts.unbookmarkPost', () => postsApi.unbookmarkPost('p1'), 'DELETE', '/api/v1/posts/p1/bookmark'],
	['posts.addComment', () => postsApi.addComment('p1', 'yo'), 'POST', '/api/v1/posts/p1/comments', { body: 'yo' }],
	['posts.updateComment', () => postsApi.updateComment('p1', 'c1', 'yo2'), 'PUT', '/api/v1/posts/p1/comments/c1', { body: 'yo2' }],
	['posts.deleteComment', () => postsApi.deleteComment('p1', 'c1'), 'DELETE', '/api/v1/posts/p1/comments/c1'],
	// rule notes / rulebook
	['ruleNotes.submit', () => ruleNotesApi.submit('g1', 'note'), 'POST', '/api/v1/games/g1/rule-notes', { content: 'note' }],
	['ruleNotes.deleteMy', () => ruleNotesApi.deleteMy('g1'), 'DELETE', '/api/v1/games/g1/rule-notes/my'],
	['rulebook.getStatus', () => rulebookApi.getStatus('g1'), 'GET', '/api/v1/games/g1/rulebook/status'],
	['rulebook.generate', () => rulebookApi.generate('g1'), 'POST', '/api/v1/games/g1/rulebook/generate', {}],
	['rulebook.getRulebook', () => rulebookApi.getRulebook('rb1'), 'GET', '/api/v1/rulebooks/rb1'],
	// setup
	['setup.getStatus', () => setupApi.getStatus(), 'GET', '/api/v1/admin/setup/status'],
	['setup.checkCsv', () => setupApi.checkCsv(), 'GET', '/api/v1/admin/setup/check-csv'],
	['setup.start', () => setupApi.start('hydrate'), 'POST', '/api/v1/admin/setup/start/hydrate'],
	['setup.stop', () => setupApi.stop('rulebooks'), 'POST', '/api/v1/admin/setup/stop/rulebooks'],
	['setup.reset', () => setupApi.reset(), 'POST', '/api/v1/admin/setup/reset'],
	// upload
	['upload.presign', () => uploadApi.presign('image/png', 3), 'POST', '/api/v1/upload/presign', { contentType: 'image/png', size: 3 }],
	// users
	['users.getMe', () => usersApi.getMe(), 'GET', '/api/v1/users/me'],
	['users.getUser encodes id', () => usersApi.getUser('a b'), 'GET', '/api/v1/users/a%20b'],
	['users.updateMe', () => usersApi.updateMe({ bio: 'x' }), 'PUT', '/api/v1/users/me', { bio: 'x' }],
	['users.deleteMe sends body', () => usersApi.deleteMe({ confirm: 'DELETE' }), 'DELETE', '/api/v1/users/me', { confirm: 'DELETE' }],
	['users.changeEmail', () => usersApi.changeEmail('pw', 'n@e.w'), 'POST', '/api/v1/users/me/change-email', { currentPassword: 'pw', newEmail: 'n@e.w' }],
	['users.requestExport', () => usersApi.requestExport(), 'POST', '/api/v1/users/me/export'],
	['users.getStats', () => usersApi.getStats('u1'), 'GET', '/api/v1/users/u1/stats'],
	['users.searchUsers encodes the query', () => usersApi.searchUsers('a&b c'), 'GET', '/api/v1/users/search?q=a%26b+c&page=0&size=20'],
	['users.searchUsers paged', () => usersApi.searchUsers('ann', 2, 5), 'GET', '/api/v1/users/search?q=ann&page=2&size=5'],
	['users.getSuggestions', () => usersApi.getSuggestions(), 'GET', '/api/v1/users/suggestions?limit=10']
];

describe('endpoint contracts', () => {
	it.each(cases)('%s', async (_name, call, method, path, body) => {
		await call();
		expect(fetchMock).toHaveBeenCalledTimes(1);
		const c = lastCall(fetchMock);
		expect(c.method).toBe(method);
		expect(c.path).toBe(path);
		expect(c.url.startsWith(API_BASE)).toBe(true);
		if (body === undefined) expect(c.rawBody).toBeUndefined();
		else expect(c.body).toEqual(body);
		expect(c.headers.get('Content-Type')).toBe('application/json');
	});
});

describe('multipart uploads', () => {
	it.each([
		['admin.uploadRulebookForGame', () => adminApi.uploadRulebookForGame('g1', file), '/api/v1/admin/games/g1/rulebook'],
		['rulebook.upload', () => rulebookApi.upload('g1', file), '/api/v1/games/g1/rulebook'],
		['upload.direct', () => uploadApi.direct(file), '/api/v1/upload'],
		['users.uploadAvatar', () => usersApi.uploadAvatar(file), '/api/v1/upload/avatar']
	] as const)('%s posts FormData with the file and lets the browser set Content-Type', async (_n, call, path) => {
		await call();
		const c = lastCall(fetchMock);
		expect(c.method).toBe('POST');
		expect(c.path).toBe(path);
		expect(c.rawBody).toBeInstanceOf(FormData);
		expect((c.rawBody as FormData).get('file')).toBeInstanceOf(File);
		expect(c.headers.has('Content-Type')).toBe(false);
	});

	it('uploadAvatar returns the public URL', async () => {
		fetchMock = installFetch(() => jsonResponse(200, { publicUrl: 'https://cdn/x.png' }));
		await expect(usersApi.uploadAvatar(file)).resolves.toBe('https://cdn/x.png');
	});
});

describe('response mapping', () => {
	it('games.browse serialises every filter that is set', async () => {
		await gamesApi.browse({
			query: 'cat',
			genre: 'Party',
			minPlayers: 2,
			maxPlayers: 4,
			minPlaytime: 15,
			maxPlaytime: 60,
			minComplexity: 1,
			maxComplexity: 3,
			minRating: 7,
			page: 0,
			sort: 'rank,asc'
		});
		const url = new URL(lastCall(fetchMock).url);
		expect(url.pathname).toBe('/api/v1/games');
		expect(Object.fromEntries(url.searchParams)).toEqual({
			q: 'cat',
			genre: 'Party',
			minPlayers: '2',
			maxPlayers: '4',
			minPlaytime: '15',
			maxPlaytime: '60',
			minComplexity: '1',
			maxComplexity: '3',
			minRating: '7',
			page: '0',
			sort: 'rank,asc'
		});
	});

	it('games.browse normalises a Spring Boot 3 VIA_DTO page', async () => {
		fetchMock = installFetch(() =>
			jsonResponse(200, { content: [{ id: 'g' }], page: { number: 1, totalPages: 2, totalElements: 21 } })
		);
		const page = await gamesApi.browse({ page: 1 });
		expect(page).toMatchObject({ number: 1, totalPages: 2, totalElements: 21, last: true });
	});

	it('auth.checkUsername / checkEmail return availability and encode input', async () => {
		fetchMock = installFetch(() => jsonResponse(200, { available: true }));
		await expect(authApi.checkUsername('a+b')).resolves.toBe(true);
		expect(lastCall(fetchMock).path).toBe('/api/v1/auth/check-username?username=a%2Bb');
		fetchMock = installFetch(() => jsonResponse(200, { available: false }));
		await expect(authApi.checkEmail('x@y.z')).resolves.toBe(false);
		expect(lastCall(fetchMock).path).toBe('/api/v1/auth/check-email?email=x%40y.z');
	});

	it('users.checkUsername treats any failure as unavailable', async () => {
		fetchMock = installFetch(() => jsonResponse(200, { available: true }));
		await expect(usersApi.checkUsername('bob')).resolves.toBe(true);
		fetchMock = installFetch(() => jsonResponse(500, { error: 'x', code: 'INTERNAL' }));
		await expect(usersApi.checkUsername('bob')).resolves.toBe(false);
	});

	it('friends.searchPeople uses the unified search restricted to users', async () => {
		fetchMock = installFetch(() => jsonResponse(200, { games: [], users: [{ id: 'u1' }], events: [] }));
		await expect(friendsApi.searchPeople('ann', 5)).resolves.toEqual([{ id: 'u1' }]);
		expect(lastCall(fetchMock).path).toBe('/api/v1/search?q=ann&limit=5&type=users');
	});

	it('posts.getUserPosts unwraps the {data, meta} page', async () => {
		fetchMock = installFetch(() => jsonResponse(200, { data: [{ id: 'p1' }], meta: { total: 1 } }));
		await expect(postsApi.getUserPosts('u1')).resolves.toEqual([{ id: 'p1' }]);
		expect(lastCall(fetchMock).path).toBe('/api/v1/users/u1/posts?page=0&size=20');
	});

	it('posts.getComments is cursor-paginated', async () => {
		const pageBody = { items: [{ id: 'c1' }], nextCursor: 'n', hasMore: true };
		fetchMock = installFetch(() => jsonResponse(200, pageBody));
		await expect(postsApi.getComments('p1')).resolves.toEqual(pageBody);
		expect(lastCall(fetchMock).path).toBe('/api/v1/posts/p1/comments?limit=20');
		await postsApi.getComments('p1', 'n', 5);
		expect(lastCall(fetchMock).path).toBe('/api/v1/posts/p1/comments?limit=5&cursor=n');
	});

	it('unwraps the generic {data} ApiResponse envelope', async () => {
		fetchMock = installFetch(() => jsonResponse(200, { data: { id: 'g1', name: 'Catan' } }));
		await expect(gamesApi.getGame('g1')).resolves.toEqual({ id: 'g1', name: 'Catan' });
	});

	it('ruleNotes.getMy maps 204 and 404 to null and rethrows other errors', async () => {
		fetchMock = installFetch(() => jsonResponse(204));
		await expect(ruleNotesApi.getMy('g1')).resolves.toBeNull();
		expect(lastCall(fetchMock).path).toBe('/api/v1/games/g1/rule-notes/my');

		fetchMock = installFetch(() => jsonResponse(200, { id: 'n1', content: 'x' }));
		await expect(ruleNotesApi.getMy('g1')).resolves.toEqual({ id: 'n1', content: 'x' });

		fetchMock = installFetch(() => jsonResponse(404, { error: 'none', code: 'NOT_FOUND' }));
		await expect(ruleNotesApi.getMy('g1')).resolves.toBeNull();

		fetchMock = installFetch(() => jsonResponse(500, { error: 'boom', code: 'INTERNAL' }));
		await expect(ruleNotesApi.getMy('g1')).rejects.toMatchObject({ status: 500, code: 'INTERNAL' });
	});

	it('maps backend error bodies to ApiRequestError with code, message and status', async () => {
		fetchMock = installFetch(() => jsonResponse(409, { error: 'Already friends', code: 'ALREADY_FRIENDS' }));
		const err = await friendsApi.sendRequest('u1').catch((e: unknown) => e);
		expect(err).toBeInstanceOf(ApiRequestError);
		expect(err).toMatchObject({ code: 'ALREADY_FRIENDS', message: 'Already friends', status: 409 });
	});

	it('maps 429 Retry-After into retryAfterSeconds', async () => {
		fetchMock = installFetch(() =>
			jsonResponse(429, { error: 'Slow down', code: 'REPORT_LIMIT_EXCEEDED' }, { 'Retry-After': '42' })
		);
		await expect(reportsApi.report('user', 'u1', 'x')).rejects.toMatchObject({
			status: 429,
			retryAfterSeconds: 42
		});
	});
});

describe('uploadApi.presignAndUpload', () => {
	it('rejects files over the backend limit without any request', async () => {
		const big = { size: MAX_PRESIGNED_UPLOAD_BYTES + 1, type: 'image/png' } as File;
		await expect(uploadApi.presignAndUpload(big)).rejects.toMatchObject({
			code: 'FILE_TOO_LARGE',
			status: 413
		});
		expect(fetchMock).not.toHaveBeenCalled();
	});

	it('presigns then PUTs the file to the presigned URL with its content type', async () => {
		fetchMock = installFetch((url) =>
			url.startsWith(API_BASE)
				? jsonResponse(200, { uploadUrl: 'https://r2.test/put?sig=1', key: 'k1', publicUrl: 'https://cdn/k1' })
				: new Response(null, { status: 200 })
		);
		await expect(uploadApi.presignAndUpload(file)).resolves.toEqual({ publicUrl: 'https://cdn/k1', key: 'k1' });
		expect(fetchMock).toHaveBeenCalledTimes(2);
		expect(callAt(fetchMock, 0).body).toEqual({ contentType: 'image/png', size: 3 });
		const put = callAt(fetchMock, 1);
		expect(put.url).toBe('https://r2.test/put?sig=1');
		expect(put.method).toBe('PUT');
		expect(put.rawBody).toBe(file);
		expect(put.headers.get('Content-Type')).toBe('image/png');
	});

	it('surfaces a failed storage PUT as UPLOAD_FAILED', async () => {
		fetchMock = installFetch(() => new Response(null, { status: 403 }));
		await expect(uploadApi.uploadFile('https://r2.test/put', file)).rejects.toMatchObject({
			code: 'UPLOAD_FAILED',
			status: 403
		});
	});
});

describe('users helpers', () => {
	it('usernameProblem enforces length and charset', () => {
		expect(usernameProblem('ab')).toBe('tooShort');
		expect(usernameProblem('a'.repeat(PROFILE_LIMITS.usernameMax + 1))).toBe('tooLong');
		expect(usernameProblem('_bob')).toBe('invalid');
		expect(usernameProblem('Bob')).toBe('invalid');
		expect(usernameProblem('bob_42')).toBeNull();
	});

	it('displayNameOf prefers display name, then username, and labels deleted users', () => {
		expect(displayNameOf({ displayName: 'Ann', username: 'ann' }, 'Deleted')).toBe('Ann');
		expect(displayNameOf({ displayName: null, username: 'ann' }, 'Deleted')).toBe('ann');
		expect(displayNameOf({ displayName: 'Ann', username: 'ann', deleted: true }, 'Deleted')).toBe('Deleted');
		expect(displayNameOf({ displayName: null, username: '' }, 'Deleted')).toBe('Deleted');
	});
});
