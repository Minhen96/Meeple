import { describe, expect, it } from 'vitest';
import { buildForwardedCookieHeader, getSetCookies, parseSetCookie } from './server';

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
