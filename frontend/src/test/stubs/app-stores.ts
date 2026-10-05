// Test stub for $app/stores (aliased in vitest.config.ts).
import { readable, writable } from 'svelte/store';

export const page = writable({
	url: new URL('http://localhost/'),
	params: {} as Record<string, string>,
	route: { id: '/' as string | null },
	status: 200,
	error: null,
	data: {} as Record<string, unknown>,
	form: undefined as unknown,
	state: {} as Record<string, unknown>
});
export const navigating = readable(null);
export const updated = { subscribe: readable(false).subscribe, check: async () => false };
