import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CursorPage } from '$lib/types';
import { CursorPager, preferExisting, reachedScrollDepth, type PagerState } from './cursorPager';
import { tokenizeMentions } from './mentions';
import { postUrl, shareLink } from './share';
import { daysUntil, displayName, greetingKey, splitTemplate, timeAgo } from './format';
import {
	MAX_RECENT_SEARCHES,
	addRecentSearch,
	loadRecentSearches,
	recentSearchesKey,
	saveRecentSearches
} from './recentSearches';

// ─── Cursor pager ───────────────────────────────────────────────────────────

interface Row {
	id: string;
}

function page(ids: string[], nextCursor: string | null): CursorPage<Row> {
	return {
		items: ids.map((id) => ({ id })),
		nextCursor,
		hasMore: nextCursor !== null
	};
}

function deferred<T>() {
	let resolve!: (value: T) => void;
	let reject!: (reason: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
}

describe('reachedScrollDepth', () => {
	it('triggers at 80% of the scrollable height', () => {
		expect(reachedScrollDepth(0, 800, 2000)).toBe(false);
		expect(reachedScrollDepth(799, 800, 2000)).toBe(false);
		expect(reachedScrollDepth(800, 800, 2000)).toBe(true);
	});

	it('treats content shorter than the viewport as fully scrolled', () => {
		expect(reachedScrollDepth(0, 800, 600)).toBe(true);
	});
});

describe('CursorPager', () => {
	it('loads pages in order with the returned cursor and stops at the end', async () => {
		const fetch = vi
			.fn<[string | null], Promise<CursorPage<Row>>>()
			.mockResolvedValueOnce(page(['a', 'b'], 'c1'))
			.mockResolvedValueOnce(page(['c'], null));
		const states: PagerState<Row>[] = [];
		const pager = new CursorPager(
			fetch,
			(r) => r.id,
			(s) => states.push(s)
		);

		await pager.loadMore();
		expect(fetch).toHaveBeenLastCalledWith(null);
		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['a', 'b']);
		expect(pager.snapshot.hasMore).toBe(true);
		expect(states[0].loading).toBe(true);

		const second = pager.loadMore();
		expect(pager.snapshot.loadingMore).toBe(true);
		await second;
		expect(fetch).toHaveBeenLastCalledWith('c1');
		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['a', 'b', 'c']);
		expect(pager.snapshot.hasMore).toBe(false);

		await pager.loadMore();
		expect(fetch).toHaveBeenCalledTimes(2);
	});

	it('never runs two requests at once and drops duplicate items across pages', async () => {
		const first = deferred<CursorPage<Row>>();
		const fetch = vi
			.fn<[string | null], Promise<CursorPage<Row>>>()
			.mockReturnValueOnce(first.promise)
			.mockResolvedValueOnce(page(['b', 'c'], null));
		const pager = new CursorPager(fetch, (r) => r.id);

		const a = pager.loadMore();
		const b = pager.loadMore();
		expect(fetch).toHaveBeenCalledTimes(1);
		first.resolve(page(['a', 'b'], 'x'));
		await Promise.all([a, b]);

		await pager.loadMore();
		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['a', 'b', 'c']);
	});

	it('keeps items on error and retries the same cursor', async () => {
		const fetch = vi
			.fn<[string | null], Promise<CursorPage<Row>>>()
			.mockResolvedValueOnce(page(['a'], 'c1'))
			.mockRejectedValueOnce(new Error('offline'))
			.mockResolvedValueOnce(page(['b'], null));
		const pager = new CursorPager(fetch, (r) => r.id);

		await pager.loadMore();
		await pager.loadMore();
		expect(pager.snapshot.error).toBeInstanceOf(Error);
		expect(pager.snapshot.items).toHaveLength(1);
		expect(pager.snapshot.loadingMore).toBe(false);

		await pager.loadMore();
		expect(fetch).toHaveBeenLastCalledWith('c1');
		expect(pager.snapshot.error).toBeNull();
		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['a', 'b']);
	});

	it('refresh discards an in-flight page and restarts from the first page', async () => {
		const stale = deferred<CursorPage<Row>>();
		const fetch = vi
			.fn<[string | null], Promise<CursorPage<Row>>>()
			.mockResolvedValueOnce(page(['a'], 'c1'))
			.mockReturnValueOnce(stale.promise)
			.mockResolvedValueOnce(page(['new'], null));
		const pager = new CursorPager(fetch, (r) => r.id);
		await pager.loadMore();

		const pending = pager.loadMore();
		await pager.refresh();
		stale.resolve(page(['old'], null));
		await pending;

		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['new']);
		expect(fetch).toHaveBeenLastCalledWith(null);
	});

	it('dispose ignores in-flight pages and every later call', async () => {
		const stale = deferred<CursorPage<Row>>();
		const fetch = vi.fn<[string | null], Promise<CursorPage<Row>>>().mockReturnValueOnce(stale.promise);
		const onChange = vi.fn();
		const pager = new CursorPager(fetch, (r) => r.id, onChange);
		const pending = pager.loadMore();
		onChange.mockClear();

		pager.dispose();
		expect(pager.disposed).toBe(true);
		stale.resolve(page(['old'], 'c1'));
		await pending;
		await pager.loadMore();
		await pager.refresh();
		pager.update(() => [{ id: 'x' }]);

		expect(onChange).not.toHaveBeenCalled();
		expect(fetch).toHaveBeenCalledTimes(1);
		expect(pager.snapshot.items).toEqual([]);
	});

	it('starts from an initial page and supports local updates', async () => {
		const fetch = vi
			.fn<[string | null], Promise<CursorPage<Row>>>()
			.mockResolvedValue(page(['z'], null));
		const pager = new CursorPager(fetch, (r) => r.id, undefined, page(['a', 'b'], 'next'));
		expect(pager.snapshot.loaded).toBe(true);

		pager.update((items) => items.filter((r) => r.id !== 'a'));
		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['b']);

		await pager.loadMore();
		expect(fetch).toHaveBeenCalledWith('next');
		expect(pager.snapshot.items.map((r) => r.id)).toEqual(['b', 'z']);
	});

	it('preferExisting keeps locally edited items and adds new ones in server order', () => {
		const liked = { id: 'a', liked: true };
		const merged = preferExisting(
			[liked, { id: 'b', liked: false }],
			[
				{ id: 'a', liked: false },
				{ id: 'b', liked: false },
				{ id: 'c', liked: false }
			],
			(r) => r.id
		);
		expect(merged[0]).toBe(liked);
		expect(merged.map((r) => r.id)).toEqual(['a', 'b', 'c']);
		const next = [{ id: 'x', liked: false }];
		expect(preferExisting([], next, (r) => r.id)).toBe(next);
	});

	it('a first-page error leaves the list unloaded so loadMore retries from the start', async () => {
		const fetch = vi
			.fn<[string | null], Promise<CursorPage<Row>>>()
			.mockRejectedValueOnce(new Error('500'))
			.mockResolvedValueOnce(page([], null));
		const pager = new CursorPager(fetch, (r) => r.id);
		await pager.loadMore();
		expect(pager.snapshot.loaded).toBe(false);
		expect(pager.snapshot.error).toBeTruthy();
		await pager.loadMore();
		expect(fetch).toHaveBeenLastCalledWith(null);
		expect(pager.snapshot.loaded).toBe(true);
		expect(pager.snapshot.hasMore).toBe(false);
	});
});

// ─── Mentions ───────────────────────────────────────────────────────────────

describe('tokenizeMentions', () => {
	it('splits text and mentions, lower-casing usernames', () => {
		expect(tokenizeMentions('GG @Alice and @bob_99!')).toEqual([
			{ type: 'text', value: 'GG ' },
			{ type: 'mention', value: '@Alice', username: 'alice' },
			{ type: 'text', value: ' and ' },
			{ type: 'mention', value: '@bob_99', username: 'bob_99' },
			{ type: 'text', value: '!' }
		]);
	});

	it('ignores e-mail addresses and names that are too short or too long', () => {
		const long = 'x'.repeat(31);
		expect(tokenizeMentions(`mail a@host.com @ab @${long}`).every((s) => s.type === 'text')).toBe(
			true
		);
		expect(tokenizeMentions('')).toEqual([]);
		expect(tokenizeMentions('@carol')).toEqual([
			{ type: 'mention', value: '@carol', username: 'carol' }
		]);
	});
});

// ─── Formatting ─────────────────────────────────────────────────────────────

describe('format helpers', () => {
	const now = new Date('2026-10-05T12:00:00Z');

	it('formats relative times', () => {
		expect(timeAgo('2026-10-05T11:59:30Z', now)).toBe('Just now');
		expect(timeAgo('2026-10-05T11:55:00Z', now)).toBe('5m ago');
		expect(timeAgo('2026-10-05T09:00:00Z', now)).toBe('3h ago');
		expect(timeAgo('2026-10-03T12:00:00Z', now)).toBe('2d ago');
		expect(timeAgo('2026-09-01T12:00:00Z', now)).not.toContain('ago');
	});

	it('counts whole calendar days until an event', () => {
		const local = new Date(2026, 9, 5, 20, 0);
		expect(daysUntil(new Date(2026, 9, 5, 22, 0).toISOString(), local)).toBe(0);
		expect(daysUntil(new Date(2026, 9, 6, 8, 0).toISOString(), local)).toBe(1);
		expect(daysUntil(new Date(2026, 9, 9, 8, 0).toISOString(), local)).toBe(4);
		expect(daysUntil(new Date(2026, 9, 5, 19, 0).toISOString(), local)).toBeNull();
	});

	it('picks the greeting by hour', () => {
		expect(greetingKey(6)).toBe('social.home.morning');
		expect(greetingKey(12)).toBe('social.home.afternoon');
		expect(greetingKey(18)).toBe('social.home.evening');
		expect(greetingKey(3)).toBe('social.home.evening');
	});

	it('renders deleted users and falls back to the username', () => {
		expect(displayName({ username: 'ana', displayName: null })).toBe('ana');
		expect(displayName({ username: 'ana', displayName: 'Ana' })).toBe('Ana');
		expect(displayName({ username: 'ana', displayName: 'Ana', deleted: true })).toBe(
			'Deleted User'
		);
	});

	it('splits a template around a slot', () => {
		expect(splitTemplate('{name} added {game} here', 'game')).toEqual(['{name} added ', ' here']);
		expect(splitTemplate('no slot', 'game')).toEqual(['no slot', '']);
	});
});

// ─── Recent searches ────────────────────────────────────────────────────────

describe('recent searches', () => {
	let store: Map<string, string>;

	beforeEach(() => {
		store = new Map();
		vi.stubGlobal('localStorage', {
			getItem: (k: string) => store.get(k) ?? null,
			setItem: (k: string, v: string) => void store.set(k, v),
			removeItem: (k: string) => void store.delete(k)
		});
	});

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('adds to the front, de-duplicates case-insensitively and caps the list', () => {
		let list: string[] = [];
		for (let i = 0; i < 10; i++) list = addRecentSearch(list, `q${i}`);
		expect(list).toHaveLength(MAX_RECENT_SEARCHES);
		expect(list[0]).toBe('q9');
		list = addRecentSearch(list, '  Q5 ');
		expect(list[0]).toBe('Q5');
		expect(list.filter((q) => q.toLowerCase() === 'q5')).toHaveLength(1);
		expect(addRecentSearch(list, '   ')).toBe(list);
	});

	it('persists per user and clears', () => {
		saveRecentSearches('u1', ['catan', 'ana']);
		expect(loadRecentSearches('u1')).toEqual(['catan', 'ana']);
		expect(loadRecentSearches('u2')).toEqual([]);
		saveRecentSearches('u1', []);
		expect(store.has(recentSearchesKey('u1'))).toBe(false);
	});

	it('survives garbage and unavailable storage', () => {
		store.set(recentSearchesKey('u1'), '{not json');
		expect(loadRecentSearches('u1')).toEqual([]);
		store.set(recentSearchesKey('u1'), JSON.stringify(['ok', 3, '', null]));
		expect(loadRecentSearches('u1')).toEqual(['ok']);

		vi.stubGlobal('localStorage', {
			getItem: () => {
				throw new Error('blocked');
			},
			setItem: () => {
				throw new Error('quota');
			},
			removeItem: () => {
				throw new Error('blocked');
			}
		});
		expect(loadRecentSearches('u1')).toEqual([]);
		expect(() => saveRecentSearches('u1', ['x'])).not.toThrow();
	});
});

// ─── Share ──────────────────────────────────────────────────────────────────

describe('shareLink', () => {
	const url = 'https://meeple.test/posts/1';

	it('uses the native share sheet when available', async () => {
		const share = vi.fn().mockResolvedValue(undefined);
		const writeText = vi.fn();
		expect(await shareLink(url, 't', { share, writeText })).toBe('shared');
		expect(share).toHaveBeenCalledWith({ url, title: 't' });
		expect(writeText).not.toHaveBeenCalled();
	});

	it('treats a dismissed share sheet as cancelled', async () => {
		const share = vi.fn().mockRejectedValue(new DOMException('closed', 'AbortError'));
		expect(await shareLink(url, 't', { share, writeText: vi.fn() })).toBe('cancelled');
	});

	it('falls back to the clipboard when sharing is unavailable or fails', async () => {
		const writeText = vi.fn().mockResolvedValue(undefined);
		expect(await shareLink(url, 't', { writeText })).toBe('copied');
		const share = vi.fn().mockRejectedValue(new DOMException('no', 'NotAllowedError'));
		expect(await shareLink(url, 't', { share, writeText })).toBe('copied');
		expect(writeText).toHaveBeenCalledWith(url);
	});

	it('reports failure when nothing works', async () => {
		expect(await shareLink(url, 't', {})).toBe('failed');
		expect(
			await shareLink(url, 't', {
				writeText: vi.fn().mockRejectedValue(new Error('denied'))
			})
		).toBe('failed');
		expect(postUrl('abc', 'https://x.test')).toBe('https://x.test/posts/abc');
	});
});
