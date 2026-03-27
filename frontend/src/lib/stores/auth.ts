import { writable, derived } from 'svelte/store';
import type { User } from '$lib/types';

export const currentUser = writable<User | null>(null);

export const isAuthenticated = derived(currentUser, ($user) => $user !== null);

export function setUser(user: User | null) {
	currentUser.set(user);
}
