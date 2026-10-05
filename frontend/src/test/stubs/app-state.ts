// Test stub for $app/state (aliased in vitest.config.ts). Mutate `page` in a test to simulate a route.
export const page = {
	url: new URL('http://localhost/'),
	params: {} as Record<string, string>,
	route: { id: '/' as string | null },
	status: 200,
	error: null as { message: string } | null,
	data: {} as Record<string, unknown>,
	form: undefined as unknown,
	state: {} as Record<string, unknown>
};
export const navigating = {
	from: null,
	to: null,
	type: null,
	willUnload: null,
	delta: null,
	complete: null
};
export const updated = { current: false, check: async () => false };
