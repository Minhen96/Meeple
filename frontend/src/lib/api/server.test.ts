import { describe, expect, it, vi } from 'vitest';
import {
	buildForwardedCookieHeader,
	getSetCookies,
	parseSetCookie,
	refreshSession
} from './server';

describe('parseSetCookie', () => {
	it('parses value and attributes', () => {
		const c = parseSetCookie(
			'access_token=a.b.c; Path=/; Domain=.example.com; Max-Age=900; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Secure; HttpOnly; SameSite=Lax'
		);
		expect(c).toMatchObject({
			name: 'access_token',
			value: 'a.b.c',
			path: '/',
			domain: '.example.com',
			maxAge: 900,
			httpOnly: true,
			secure: true,
			sameSite: 'lax'
		});
		expect(c?.expires?.toISOString()).toBe('2026-10-21T07:28:00.000Z');
	});

	it('rejects malformed headers', () => {
		expect(parseSetCookie('novalue')).toBeNull();
		expect(parseSetCookie('=value; Path=/')).toBeNull();
	});

	it('parses Max-Age=0 deletions with an empty value', () => {
		const c = parseSetCookie(
			'refresh_token=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly'
		);
		expect(c).toMatchObject({ name: 'refresh_token', value: '', maxAge: 0, httpOnly: true });
		expect(c?.expires?.getTime()).toBe(0);
	});

	it('keeps negative Max-Age (also a deletion)', () => {
		expect(parseSetCookie('a=b; Max-Age=-1')?.maxAge).toBe(-1);
	});

	it('ignores an empty or non-numeric Max-Age instead of treating it as 0', () => {
		expect(parseSetCookie('a=b; Max-Age=')?.maxAge).toBeUndefined();
		expect(parseSetCookie('a=b; Max-Age=abc')?.maxAge).toBeUndefined();
		expect(parseSetCookie('a=b; Max-Age=1.5')?.maxAge).toBeUndefined();
	});

	it('ignores an unparseable Expires', () => {
		expect(parseSetCookie('a=b; Expires=not a date')?.expires).toBeUndefined();
	});

	it('normalises attribute names and SameSite values case-insensitively', () => {
		expect(parseSetCookie('a=b; SAMESITE=STRICT; secure; HTTPONLY; path=/x')).toMatchObject({
			sameSite: 'strict',
			secure: true,
			httpOnly: true,
			path: '/x'
		});
		expect(parseSetCookie('a=b; SameSite=None; Secure')?.sameSite).toBe('none');
		expect(parseSetCookie('a=b; SameSite=bogus')?.sameSite).toBeUndefined();
	});

	it('keeps "=" inside the value', () => {
		expect(parseSetCookie('token=abc==; Path=/')?.value).toBe('abc==');
	});
});

describe('getSetCookies', () => {
	it('returns each Set-Cookie header separately', () => {
		const headers = new Headers();
		headers.append('Set-Cookie', 'access_token=x; Path=/; Expires=Wed, 21 Oct 2026 07:28:00 GMT');
		headers.append('Set-Cookie', 'refresh_token=y; Path=/');
		expect(getSetCookies(headers).map((h) => parseSetCookie(h)?.name)).toEqual([
			'access_token',
			'refresh_token'
		]);
	});

	it('splits a combined header without breaking Expires dates (no getSetCookie)', () => {
		const combined =
			'access_token=x; Path=/; Expires=Wed, 21 Oct 2026 07:28:00 GMT; HttpOnly, ' +
			'refresh_token=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT';
		const headers = { get: (name: string) => (name === 'set-cookie' ? combined : null) };

		const parsed = getSetCookies(headers as unknown as Headers).map(parseSetCookie);

		expect(parsed).toHaveLength(2);
		expect(parsed[0]).toMatchObject({ name: 'access_token', value: 'x', httpOnly: true });
		expect(parsed[0]?.expires?.toISOString()).toBe('2026-10-21T07:28:00.000Z');
		expect(parsed[1]).toMatchObject({ name: 'refresh_token', value: '', maxAge: 0 });
	});
});

describe('refreshSession', () => {
	function respond(status: number, body: unknown, setCookies: string[] = []) {
		const headers = new Headers({ 'Content-Type': 'application/json' });
		for (const c of setCookies) headers.append('Set-Cookie', c);
		return vi.fn(async () => new Response(JSON.stringify(body), { status, headers }));
	}

	it('returns rotated tokens on success', async () => {
		const fetchFn = respond(200, {}, [
			'access_token=new-a; Path=/; Max-Age=900; HttpOnly',
			'refresh_token=new-r; Path=/; Max-Age=604800; HttpOnly'
		]);

		const res = await refreshSession(fetchFn, 'old-r');

		expect(res).toMatchObject({ kind: 'refreshed', accessToken: 'new-a', refreshToken: 'new-r' });
		const init = (fetchFn.mock.calls[0] as unknown as [string, RequestInit])[1];
		expect(new Headers(init.headers).get('cookie')).toBe('refresh_token=old-r');
	});

	it('keeps the backend cookie deletions when the token is rejected', async () => {
		const res = await refreshSession(
			respond(401, { code: 'TOKEN_REUSED' }, [
				'access_token=; Path=/; Domain=.example.com; Max-Age=0',
				'refresh_token=; Path=/; Domain=.example.com; Max-Age=0'
			]),
			'r'
		);

		expect(res.kind).toBe('rejected');
		expect(res.kind === 'rejected' && res.cookies.map((c) => [c.name, c.maxAge, c.domain])).toEqual([
			['access_token', 0, '.example.com'],
			['refresh_token', 0, '.example.com']
		]);
	});

	it('reports a 409 REFRESH_RACE as a race', async () => {
		expect(await refreshSession(respond(409, { code: 'REFRESH_RACE' }), 'r')).toEqual({
			kind: 'race'
		});
	});

	it('treats other failures as unavailable', async () => {
		expect((await refreshSession(respond(409, { code: 'OTHER' }), 'r')).kind).toBe('unavailable');
		expect((await refreshSession(respond(503, {}), 'r')).kind).toBe('unavailable');
		const network = vi.fn(async () => {
			throw new TypeError('fetch failed');
		});
		expect(await refreshSession(network, 'r')).toEqual({ kind: 'unavailable', cookies: [] });
	});
});

describe('buildForwardedCookieHeader', () => {
	it('overrides rotated tokens and keeps other cookies', () => {
		expect(
			buildForwardedCookieHeader('access_token=old; theme=dark; refresh_token=r1', {
				access_token: 'new',
				refresh_token: undefined
			})
		).toBe('access_token=new; theme=dark; refresh_token=r1');
	});

	it('returns null when there is nothing to forward', () => {
		expect(buildForwardedCookieHeader(null, {})).toBeNull();
	});
});
