// @vitest-environment jsdom
// auth, library and peopleSearch stores.
import { get } from 'svelte/store';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { User } from '$lib/types';

const env = vi.hoisted(() => ({ browser: true }));
vi.mock('$app/environment', () => ({
	get browser() {
		return env.browser;
	}
}));

const user = (id: string) => ({ id, username: id }) as User;
const person = (id: string) => ({ id, username: id, displayName: null, avatarUrl: null });

beforeEach(() => {
	vi.resetModules();
	localStorage.clear();
	env.browser = true;
});

describe('auth store', () => {
	it('tracks the current user and derived isAuthenticated', async () => {
		const { currentUser, isAuthenticated, setUser } = await import('./auth');
		expect(get(isAuthenticated)).toBe(false);
		setUser(user('u1'));
		expect(get(currentUser)?.id).toBe('u1');
		expect(get(isAuthenticated)).toBe(true);
		setUser(null);
		expect(get(isAuthenticated)).toBe(false);
	});
});

describe('library store', () => {
	it('starts from the default browse state', async () => {
		const { libraryStore, defaultState } = await import('./library');
		expect(get(libraryStore)).toEqual(defaultState);
		expect(defaultState).toMatchObject({ activeTab: 'all', sortOption: 'rank,asc', selectedGenre: '' });
		expect(defaultState.gamesPage).toMatchObject({ content: [], last: true });
	});
});

describe('peopleSearchHistory', () => {
	async function load() {
		const auth = await import('./auth');
		const { peopleSearchHistory } = await import('./peopleSearch');
		return { ...auth, history: peopleSearchHistory };
	}

	it('is empty and does not persist while signed out', async () => {
		const { history } = await load();
		history.add(person('a'));
		expect(get(history).map((p) => p.id)).toEqual(['a']);
		expect(localStorage.length).toBe(0);
	});

	it('loads, adds (deduped, newest first, max 10) and persists per user', async () => {
		localStorage.setItem('people_search_history_u1', JSON.stringify([person('old')]));
		const { history, setUser } = await load();
		setUser(user('u1'));
		expect(get(history).map((p) => p.id)).toEqual(['old']);

		for (let i = 0; i < 12; i++) history.add({ ...person(`p${i}`), extra: 'dropped' } as ReturnType<typeof person>);
		history.add(person('p5'));
		const ids = get(history).map((p) => p.id);
		expect(ids).toHaveLength(10);
		expect(ids[0]).toBe('p5');
		expect(ids.filter((id) => id === 'p5')).toHaveLength(1);

		const stored = JSON.parse(localStorage.getItem('people_search_history_u1') ?? '[]');
		expect(stored.map((p: { id: string }) => p.id)).toEqual(ids);
		expect(stored[1]).not.toHaveProperty('extra');
	});

	it('switches history when the user changes and clears on logout', async () => {
		localStorage.setItem('people_search_history_u1', JSON.stringify([person('a')]));
		localStorage.setItem('people_search_history_u2', JSON.stringify([person('b')]));
		const { history, setUser } = await load();
		setUser(user('u1'));
		expect(get(history).map((p) => p.id)).toEqual(['a']);
		setUser(user('u2'));
		expect(get(history).map((p) => p.id)).toEqual(['b']);
		setUser(null);
		expect(get(history)).toEqual([]);
	});

	it('remove and clear update storage (empty list removes the key)', async () => {
		localStorage.setItem('people_search_history_u1', JSON.stringify([person('a'), person('b')]));
		const { history, setUser } = await load();
		setUser(user('u1'));
		history.remove('a');
		expect(get(history).map((p) => p.id)).toEqual(['b']);
		expect(JSON.parse(localStorage.getItem('people_search_history_u1') ?? '[]')).toHaveLength(1);
		history.clear();
		expect(get(history)).toEqual([]);
		expect(localStorage.getItem('people_search_history_u1')).toBeNull();
	});

	it('ignores garbage and invalid entries in storage', async () => {
		localStorage.setItem('people_search_history_u1', '{not json');
		localStorage.setItem(
			'people_search_history_u2',
			JSON.stringify([person('ok'), { id: 1 }, null, 'x', { id: 'noname' }])
		);
		localStorage.setItem('people_search_history_u3', JSON.stringify({ id: 'obj' }));
		const { history, setUser } = await load();
		setUser(user('u1'));
		expect(get(history)).toEqual([]);
		setUser(user('u2'));
		expect(get(history).map((p) => p.id)).toEqual(['ok']);
		setUser(user('u3'));
		expect(get(history)).toEqual([]);
	});

	it('survives a storage that throws on write', async () => {
		const { history, setUser } = await load();
		setUser(user('u1'));
		const spy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
			throw new Error('quota');
		});
		expect(() => history.add(person('a'))).not.toThrow();
		expect(get(history).map((p) => p.id)).toEqual(['a']);
		spy.mockRestore();
	});

	it('does not read or write storage outside the browser', async () => {
		env.browser = false;
		localStorage.setItem('people_search_history_u1', JSON.stringify([person('a')]));
		const { history, setUser } = await load();
		setUser(user('u1'));
		expect(get(history)).toEqual([]);
		history.add(person('b'));
		expect(JSON.parse(localStorage.getItem('people_search_history_u1') ?? '[]')).toHaveLength(1);
	});
});
