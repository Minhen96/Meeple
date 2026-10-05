import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';
import { currentUser } from './auth';

/** A recently opened profile from People search. */
export interface RecentPerson {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
}

const BASE_STORAGE_KEY = 'people_search_history';
const MAX_ENTRIES = 10;

/** localStorage can be unavailable (private mode, blocked site data) or hold garbage. */
function read(key: string): RecentPerson[] {
	try {
		const raw = localStorage.getItem(key);
		const parsed: unknown = raw ? JSON.parse(raw) : [];
		return Array.isArray(parsed)
			? parsed.filter(
					(p): p is RecentPerson =>
						typeof p === 'object' &&
						p !== null &&
						typeof p.id === 'string' &&
						typeof p.username === 'string'
				)
			: [];
	} catch {
		return [];
	}
}

function write(key: string, list: RecentPerson[]) {
	try {
		if (list.length === 0) localStorage.removeItem(key);
		else localStorage.setItem(key, JSON.stringify(list));
	} catch {
		// history is a convenience; ignore storage failures
	}
}

function createPeopleSearchHistory() {
	const { subscribe, set, update } = writable<RecentPerson[]>([]);

	const scopedKey = () => {
		const user = get(currentUser);
		return user ? `${BASE_STORAGE_KEY}_${user.id}` : null;
	};

	if (browser) {
		currentUser.subscribe(($user) => set($user ? read(`${BASE_STORAGE_KEY}_${$user.id}`) : []));
	}

	function persist(list: RecentPerson[]) {
		const key = scopedKey();
		if (browser && key) write(key, list);
	}

	return {
		subscribe,
		add: (person: RecentPerson) => {
			update((history) => {
				const entry: RecentPerson = {
					id: person.id,
					username: person.username,
					displayName: person.displayName,
					avatarUrl: person.avatarUrl
				};
				const next = [entry, ...history.filter((u) => u.id !== person.id)].slice(0, MAX_ENTRIES);
				persist(next);
				return next;
			});
		},
		remove: (userId: string) => {
			update((history) => {
				const next = history.filter((u) => u.id !== userId);
				persist(next);
				return next;
			});
		},
		clear: () => {
			persist([]);
			set([]);
		}
	};
}

export const peopleSearchHistory = createPeopleSearchHistory();
