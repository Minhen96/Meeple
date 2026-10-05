// Branch coverage for the root layout's session load, with the backend helpers mocked
// (the end-to-end cookie flows live in layout.server.test.ts).
import { isRedirect } from '@sveltejs/kit';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { ParsedSetCookie, RefreshResult } from '$lib/api/server';

const privateEnv = vi.hoisted(() => ({ COOKIE_DOMAIN: undefined as string | undefined }));
const server = vi.hoisted(() => ({
	fetchMe: vi.fn(),
	refreshSession: vi.fn()
}));
vi.mock('$env/dynamic/private', () => ({ env: privateEnv }));
vi.mock('$lib/api/server', async (importOriginal) => ({
	...(await importOriginal<typeof import('$lib/api/server')>()),
	fetchMe: server.fetchMe,
	refreshSession: server.refreshSession
}));

const { load } = await import('./+layout.server');
type LoadEvent = Parameters<typeof load>[0];

interface Write {
	op: 'set' | 'delete';
	name: string;
	value?: string;
	opts: { domain?: string; path?: string };
}

async function run(path: string, jar: Record<string, string>, locals: Record<string, unknown> = {}) {
	const writes: Write[] = [];
	const cookies = {
		get: (n: string) => jar[n],
		set: (name: string, value: string, opts: Write['opts']) => writes.push({ op: 'set', name, value, opts }),
		delete: (name: string, opts: Write['opts']) => writes.push({ op: 'delete', name, opts })
	};
	const event = {
		cookies,
		url: new URL(`http://app.test${path}`),
		fetch: vi.fn(),
		locals
	} as unknown as LoadEvent;
	try {
		return { result: (await load(event)) as Record<string, unknown>, thrown: null, writes, locals };
	} catch (err) {
		return { result: null, thrown: err, writes, locals };
	}
}

function expectRedirect(thrown: unknown, status: number, location: string) {
	expect(isRedirect(thrown)).toBe(true);
	expect(thrown).toMatchObject({ status, location });
}

const USER = { id: 'u1', username: 'meeple', onboardingCompleted: true };
const cookie = (name: string, extra: Partial<ParsedSetCookie> = {}): ParsedSetCookie => ({
	name,
	value: 'v',
	httpOnly: true,
	secure: true,
	...extra
});

beforeEach(() => {
	privateEnv.COOKIE_DOMAIN = undefined;
	server.fetchMe.mockReset();
	server.refreshSession.mockReset();
});

describe('anonymous visitors', () => {
	it('redirect from private pages to login with the return path', async () => {
		const { thrown } = await run('/events?tab=past', {});
		expectRedirect(thrown, 302, '/auth/login?redirect=%2Fevents%3Ftab%3Dpast');
		expect(server.fetchMe).not.toHaveBeenCalled();
	});

	it.each(['/auth/login', '/onboarding/welcome'])('see public page %s with no user', async (path) => {
		const { result } = await run(path, {}, { locale: 'zh-CN' });
		expect(result).toEqual({ user: null, locale: 'zh-CN' });
	});

	it('defaults the locale when the hook did not set one', async () => {
		const { result } = await run('/auth/login', {});
		expect(result).toMatchObject({ locale: 'en' });
	});
});

describe('signed-in visitors', () => {
	it('return the user from a valid access token without refreshing', async () => {
		server.fetchMe.mockResolvedValue(USER);
		const { result } = await run('/library', { access_token: 'a1' });
		expect(result).toMatchObject({ user: USER });
		expect(server.fetchMe).toHaveBeenCalledWith(expect.any(Function), 'a1');
		expect(server.refreshSession).not.toHaveBeenCalled();
	});

	it('send users who have not finished onboarding to the welcome step', async () => {
		server.fetchMe.mockResolvedValue({ ...USER, onboardingCompleted: false });
		const { thrown } = await run('/library', { access_token: 'a1' });
		expectRedirect(thrown, 302, '/onboarding/welcome');
	});

	it('let un-onboarded users stay inside onboarding', async () => {
		server.fetchMe.mockResolvedValue({ ...USER, onboardingCompleted: false });
		const { result } = await run('/onboarding/profile', { access_token: 'a1' });
		expect(result).toMatchObject({ user: { id: 'u1' } });
	});

	it('redirect to login when the token is bad and there is no refresh token', async () => {
		server.fetchMe.mockResolvedValue(null);
		const { thrown } = await run('/library', { access_token: 'bad' });
		expectRedirect(thrown, 302, '/auth/login?redirect=%2Flibrary');
	});
});

describe('server-side refresh outcomes', () => {
	it('refreshed without tokens in the response: keeps locals and has no user', async () => {
		server.refreshSession.mockResolvedValue({
			kind: 'refreshed',
			cookies: [],
			accessToken: null,
			refreshToken: null
		} satisfies RefreshResult);
		const { thrown, locals } = await run('/library', { refresh_token: 'r1' });
		expectRedirect(thrown, 302, '/auth/login?redirect=%2Flibrary');
		expect(locals).toEqual({});
		expect(server.fetchMe).not.toHaveBeenCalled();
	});

	it('refreshed: forwards cookies (default path "/") and stores rotated tokens in locals', async () => {
		server.refreshSession.mockResolvedValue({
			kind: 'refreshed',
			cookies: [cookie('access_token', { value: 'a2' })],
			accessToken: 'a2',
			refreshToken: 'r2'
		} satisfies RefreshResult);
		server.fetchMe.mockResolvedValue(USER);
		const { result, writes, locals } = await run('/library', { refresh_token: 'r1' });
		expect(result).toMatchObject({ user: USER });
		expect(locals).toMatchObject({ accessToken: 'a2', refreshToken: 'r2' });
		expect(writes).toContainEqual(
			expect.objectContaining({ op: 'set', name: 'access_token', value: 'a2', opts: expect.objectContaining({ path: '/' }) })
		);
		expect(server.fetchMe).toHaveBeenCalledWith(expect.any(Function), 'a2');
	});

	it('race on the retried request falls through instead of redirecting forever', async () => {
		server.refreshSession.mockResolvedValue({ kind: 'race' } satisfies RefreshResult);
		const { thrown, writes } = await run('/library', { refresh_token: 'r1', refresh_race_retry: '1' });
		// Retry marker cleared, then no user → login (not another 307).
		expect(writes).toContainEqual(expect.objectContaining({ op: 'delete', name: 'refresh_race_retry' }));
		expectRedirect(thrown, 302, '/auth/login?redirect=%2Flibrary');
	});

	it('rejected: deletes auth cookies host-only, on COOKIE_DOMAIN and on backend domains', async () => {
		privateEnv.COOKIE_DOMAIN = '.meeple.test';
		server.refreshSession.mockResolvedValue({
			kind: 'rejected',
			cookies: [cookie('refresh_token', { value: '', domain: 'api.meeple.test', maxAge: 0 })]
		} satisfies RefreshResult);
		const { writes } = await run('/auth/login', { refresh_token: 'r1' });
		const deletions = writes.filter((w) => w.op === 'delete').map((w) => `${w.name}@${w.opts.domain ?? 'host'}`);
		expect(deletions.sort()).toEqual(
			[
				'access_token@host',
				'access_token@.meeple.test',
				'access_token@api.meeple.test',
				'refresh_token@host',
				'refresh_token@.meeple.test',
				'refresh_token@api.meeple.test'
			].sort()
		);
	});

	it('unavailable: keeps the session cookies, forwards whatever the backend sent', async () => {
		server.refreshSession.mockResolvedValue({
			kind: 'unavailable',
			cookies: [cookie('other', { path: '/x' })]
		} satisfies RefreshResult);
		const { result, writes } = await run('/auth/login', { refresh_token: 'r1' });
		expect(result).toMatchObject({ user: null });
		expect(writes).toEqual([
			expect.objectContaining({ op: 'set', name: 'other', opts: expect.objectContaining({ path: '/x' }) })
		]);
	});
});
