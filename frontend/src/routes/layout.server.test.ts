import { isRedirect } from '@sveltejs/kit';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const privateEnv = vi.hoisted(() => ({ COOKIE_DOMAIN: undefined as string | undefined }));
vi.mock('$env/dynamic/private', () => ({ env: privateEnv }));

const { load } = await import('./+layout.server');

type LoadEvent = Parameters<typeof load>[0];
type FetchArgs = [input: RequestInfo | URL, init?: RequestInit];

interface CookieWrite {
	op: 'set' | 'delete';
	name: string;
	value?: string;
	opts: { path?: string; domain?: string; maxAge?: number };
}

function fakeCookies(initial: Record<string, string>) {
	const jar = new Map(Object.entries(initial));
	const writes: CookieWrite[] = [];
	return {
		writes,
		cookies: {
			get: (name: string) => jar.get(name),
			set: (name: string, value: string, opts: CookieWrite['opts']) => {
				writes.push({ op: 'set', name, value, opts });
			},
			delete: (name: string, opts: CookieWrite['opts']) => {
				writes.push({ op: 'delete', name, opts });
			}
		}
	};
}

function json(status: number, body: unknown, setCookies: string[] = []): Response {
	const headers = new Headers({ 'Content-Type': 'application/json' });
	for (const c of setCookies) headers.append('Set-Cookie', c);
	return new Response(JSON.stringify(body), { status, headers });
}

const USER = { id: 'u1', username: 'meeple', onboardingCompleted: true };

async function run(
	path: string,
	initialCookies: Record<string, string>,
	backend: (url: string) => Response
) {
	const { cookies, writes } = fakeCookies(initialCookies);
	const fetchMock = vi.fn(async (...[input]: FetchArgs) => backend(String(input)));
	const event = {
		cookies,
		url: new URL(`http://app.test${path}`),
		fetch: fetchMock,
		locals: {}
	} as unknown as LoadEvent;

	let result: unknown;
	let thrown: unknown;
	try {
		result = await load(event);
	} catch (err) {
		thrown = err;
	}
	return { result, thrown, writes, locals: event.locals };
}

beforeEach(() => {
	privateEnv.COOKIE_DOMAIN = undefined;
});

describe('root layout server load', () => {
	it('refreshes an expired access token and forwards the rotated cookies', async () => {
		const { result, writes, locals } = await run('/library', { refresh_token: 'r1' }, (url) => {
			if (url.endsWith('/auth/refresh')) {
				return json(200, {}, [
					'access_token=a2; Path=/; Max-Age=900; HttpOnly; Secure; SameSite=Lax',
					'refresh_token=r2; Path=/; Max-Age=604800; HttpOnly; Secure; SameSite=Lax'
				]);
			}
			return json(200, { data: USER });
		});

		expect(result).toEqual({ user: USER });
		expect(locals).toEqual({ accessToken: 'a2', refreshToken: 'r2' });
		expect(writes.filter((w) => w.op === 'set').map((w) => [w.name, w.value])).toEqual([
			['access_token', 'a2'],
			['refresh_token', 'r2']
		]);
	});

	it('on a refresh race, redirects the browser to retry the same URL once', async () => {
		const backend = (url: string) =>
			url.endsWith('/auth/refresh') ? json(409, { code: 'REFRESH_RACE' }) : json(401, {});

		const first = await run('/events?tab=mine', { refresh_token: 'r1' }, backend);

		expect(isRedirect(first.thrown)).toBe(true);
		expect(first.thrown).toMatchObject({ status: 307, location: '/events?tab=mine' });
		expect(first.writes).toContainEqual(
			expect.objectContaining({ op: 'set', name: 'refresh_race_retry' })
		);
		// No auth cookie is touched on a race.
		expect(first.writes.some((w) => w.name === 'access_token' || w.name === 'refresh_token')).toBe(
			false
		);

		// Second race in a row (retry cookie present): no redirect loop.
		const second = await run(
			'/events?tab=mine',
			{ refresh_token: 'r1', refresh_race_retry: '1' },
			backend
		);
		expect(second.thrown).toMatchObject({ status: 302 });
		expect((second.thrown as { location: string }).location).toMatch(/^\/auth\/login/);
		expect(second.writes).toContainEqual(
			expect.objectContaining({ op: 'delete', name: 'refresh_race_retry' })
		);
	});

	it('on a rejected refresh, forwards backend deletions and deletes the auth cookies', async () => {
		privateEnv.COOKIE_DOMAIN = '.meeple.test';
		const { thrown, writes } = await run('/library', { refresh_token: 'stolen' }, (url) =>
			url.endsWith('/auth/refresh')
				? json(401, { code: 'TOKEN_REUSED' }, [
						'refresh_token=; Path=/; Domain=.api.meeple.test; Max-Age=0'
					])
				: json(401, {})
		);

		expect(thrown).toMatchObject({ status: 302 });
		expect(writes).toContainEqual({
			op: 'set',
			name: 'refresh_token',
			value: '',
			opts: expect.objectContaining({ maxAge: 0, domain: '.api.meeple.test' })
		});
		const deletions = writes
			.filter((w) => w.op === 'delete')
			.map((w) => `${w.name}@${w.opts.domain ?? 'host'}${w.opts.path}`);
		for (const name of ['access_token', 'refresh_token']) {
			expect(deletions).toContain(`${name}@host/`);
			expect(deletions).toContain(`${name}@.meeple.test/`);
			expect(deletions).toContain(`${name}@.api.meeple.test/`);
		}
	});

	it('keeps the original query string in the login redirect', async () => {
		const { thrown } = await run('/events?tab=mine', {}, () => json(500, {}));
		expect(thrown).toMatchObject({
			status: 302,
			location: `/auth/login?redirect=${encodeURIComponent('/events?tab=mine')}`
		});
	});
});
