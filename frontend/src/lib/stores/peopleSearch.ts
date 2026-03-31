import { writable } from 'svelte/store';
import { browser } from '$app/environment';
import type { User } from '$lib/types';

const STORAGE_KEY = 'people_search_history';

function createPeopleSearchHistory() {
	const initial = browser ? JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]') : [];
	const { subscribe, update } = writable<User[]>(initial);

	return {
		subscribe,
		add: (user: User) => {
			update((history) => {
				// Remove if already exists and add to top
				const filtered = history.filter((u) => u.id !== user.id);
				const newHistory = [user, ...filtered].slice(0, 10);
				if (browser) {
					localStorage.setItem(STORAGE_KEY, JSON.stringify(newHistory));
				}
				return newHistory;
			});
		},
		remove: (userId: string) => {
			update((history) => {
				const newHistory = history.filter((u) => u.id !== userId);
				if (browser) {
					localStorage.setItem(STORAGE_KEY, JSON.stringify(newHistory));
				}
				return newHistory;
			});
		},
		clear: () => {
			if (browser) {
				localStorage.removeItem(STORAGE_KEY);
			}
			update(() => []);
		}
	};
}

export const peopleSearchHistory = createPeopleSearchHistory();
