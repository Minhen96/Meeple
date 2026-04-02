import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';
import type { User } from '$lib/types';
import { currentUser } from './auth';

const BASE_STORAGE_KEY = 'people_search_history';

function createPeopleSearchHistory() {
	const { subscribe, set, update } = writable<User[]>([]);

	// Helper to get scoped key
	const getScopedKey = () => {
		const user = get(currentUser);
		return user ? `${BASE_STORAGE_KEY}_${user.id}` : BASE_STORAGE_KEY;
	};

	// Sync with localStorage when user changes
	if (browser) {
		currentUser.subscribe(($user) => {
			if (!$user) {
				set([]);
				return;
			}
			const scopedKey = `${BASE_STORAGE_KEY}_${$user.id}`;
			const cached = localStorage.getItem(scopedKey);
			set(cached ? JSON.parse(cached) : []);
		});
	}

	return {
		subscribe,
		add: (user: User) => {
			update((history) => {
				const filtered = history.filter((u) => u.id !== user.id);
				const newHistory = [user, ...filtered].slice(0, 10);
				if (browser) {
					localStorage.setItem(getScopedKey(), JSON.stringify(newHistory));
				}
				return newHistory;
			});
		},
		remove: (userId: string) => {
			update((history) => {
				const newHistory = history.filter((u) => u.id !== userId);
				if (browser) {
					localStorage.setItem(getScopedKey(), JSON.stringify(newHistory));
				}
				return newHistory;
			});
		},
		clear: () => {
			if (browser) {
				localStorage.removeItem(getScopedKey());
			}
			set([]);
		}
	};
}

export const peopleSearchHistory = createPeopleSearchHistory();
