/**
 * Server-only helpers used by +layout.server.ts / hooks.server.ts.
 *
 * These run inside SvelteKit's server runtime with SvelteKit's `fetch`, never
 * in the browser, so they cannot go through the browser refresh/redirect logic
 * in client.ts. Keep all server-side calls to the backend in this module.
 */
import type { User } from '$lib/types';

export const API_BASE_URL = (import.meta.env.VITE_API_URL as string | undefined) ?? '';

/** Origin of the backend API, or null if VITE_API_URL is not a valid absolute URL. */
export const API_ORIGIN: string | null = (() => {
	try {
		return new URL(API_BASE_URL).origin;
	} catch {
		return null;
	}
})();

export const ACCESS_TOKEN_COOKIE = 'access_token';
export const REFRESH_TOKEN_COOKIE = 'refresh_token';

type FetchFn = typeof fetch;

function unwrap<T>(body: unknown): T {
	if (body && typeof body === 'object' && 'data' in body) {
		const data = (body as { data: unknown }).data;
		if (data !== undefined && data !== null) return data as T;
	}
	return body as T;
}

/** GET /api/v1/users/me with an explicit bearer token. Returns null on any failure. */
export async function fetchMe(fetchFn: FetchFn, accessToken: string): Promise<User | null> {
	try {
		const res = await fetchFn(`${API_BASE_URL}/api/v1/users/me`, {
			headers: { Authorization: `Bearer ${accessToken}` }
		});
		if (!res.ok) return null;
		return unwrap<User>(await res.json());
	} catch {
		return null;
	}
}

export interface ParsedSetCookie {
	name: string;
	value: string;
	path?: string;
	domain?: string;
	maxAge?: number;
	expires?: Date;
	httpOnly: boolean;
	secure: boolean;
	sameSite?: 'lax' | 'strict' | 'none';
}

/** Split a combined Set-Cookie header (fallback when getSetCookie() is unavailable). */
function splitCombinedSetCookie(header: string): string[] {
	// Split on commas that start a new `name=` pair, not commas inside Expires dates.
	return header.split(/,(?=\s*[^;,=\s]+=)/).map((s) => s.trim()).filter(Boolean);
}

export function getSetCookies(headers: Headers): string[] {
	if (typeof headers.getSetCookie === 'function') return headers.getSetCookie();
	const combined = headers.get('set-cookie');
	return combined ? splitCombinedSetCookie(combined) : [];
}

export function parseSetCookie(header: string): ParsedSetCookie | null {
	const [pair, ...attrs] = header.split(';');
	const eq = pair.indexOf('=');
	if (eq <= 0) return null;

	const cookie: ParsedSetCookie = {
		name: pair.slice(0, eq).trim(),
		value: pair.slice(eq + 1).trim(),
		httpOnly: false,
		secure: false
	};

	for (const attr of attrs) {
		const [rawKey, ...rest] = attr.split('=');
		const key = rawKey.trim().toLowerCase();
		const val = rest.join('=').trim();
		switch (key) {
			case 'path':
				cookie.path = val;
				break;
			case 'domain':
				cookie.domain = val;
				break;
			case 'max-age': {
				// Strict integer only: Number('') === 0 would turn a malformed
				// `Max-Age=` into a deletion.
				if (/^-?\d+$/.test(val)) cookie.maxAge = Number(val);
				break;
			}
			case 'expires': {
				const d = new Date(val);
				if (!Number.isNaN(d.getTime())) cookie.expires = d;
				break;
			}
			case 'httponly':
				cookie.httpOnly = true;
				break;
			case 'secure':
				cookie.secure = true;
				break;
			case 'samesite': {
				const v = val.toLowerCase();
				if (v === 'lax' || v === 'strict' || v === 'none') cookie.sameSite = v;
				break;
			}
		}
	}
	return cookie;
}

/** Backend error code for a refresh token that was rotated moments ago by a concurrent refresh. */
export const REFRESH_RACE_CODE = 'REFRESH_RACE';

export type RefreshResult =
	/** Tokens rotated; `cookies` carries the new access + refresh cookies. */
	| { kind: 'refreshed'; cookies: ParsedSetCookie[]; accessToken: string | null; refreshToken: string | null }
	/** Refresh token rejected (401/403); `cookies` carries any deletions the backend sent. */
	| { kind: 'rejected'; cookies: ParsedSetCookie[] }
	/** 409 REFRESH_RACE: a concurrent refresh already rotated the token; no cookie changes. */
	| { kind: 'race' }
	/** Backend unreachable or errored; `cookies` carries any Set-Cookie it still sent. */
	| { kind: 'unavailable'; cookies: ParsedSetCookie[] };

async function readErrorCode(res: Response): Promise<string | null> {
	try {
		const body = (await res.json()) as { code?: unknown };
		return typeof body.code === 'string' ? body.code : null;
	} catch {
		return null;
	}
}

/** POST /api/v1/auth/refresh with an explicit refresh token cookie. */
export async function refreshSession(
	fetchFn: FetchFn,
	refreshToken: string
): Promise<RefreshResult> {
	let res: Response;
	try {
		res = await fetchFn(`${API_BASE_URL}/api/v1/auth/refresh`, {
			method: 'POST',
			headers: {
				Cookie: `${REFRESH_TOKEN_COOKIE}=${refreshToken}`,
				'Content-Type': 'application/json'
			}
		});
	} catch {
		return { kind: 'unavailable', cookies: [] };
	}

	// Parsed for every status: a rejected refresh (e.g. reuse detection) clears
	// the cookies with Max-Age=0, and those deletions must reach the browser.
	const cookies = getSetCookies(res.headers)
		.map(parseSetCookie)
		.filter((c): c is ParsedSetCookie => c !== null);

	if (res.ok) {
		const find = (name: string) => cookies.find((c) => c.name === name)?.value || null;
		return {
			kind: 'refreshed',
			cookies,
			accessToken: find(ACCESS_TOKEN_COOKIE),
			refreshToken: find(REFRESH_TOKEN_COOKIE)
		};
	}
	if (res.status === 409 && (await readErrorCode(res)) === REFRESH_RACE_CODE) {
		return { kind: 'race' };
	}
	if (res.status === 401 || res.status === 403) return { kind: 'rejected', cookies };
	return { kind: 'unavailable', cookies };
}

/**
 * Build the Cookie header to forward to the backend: the browser's cookies,
 * with any tokens rotated earlier in this request taking precedence.
 */
export function buildForwardedCookieHeader(
	incoming: string | null,
	overrides: Record<string, string | undefined>
): string | null {
	const pairs = new Map<string, string>();
	for (const part of (incoming ?? '').split(';')) {
		const eq = part.indexOf('=');
		if (eq <= 0) continue;
		pairs.set(part.slice(0, eq).trim(), part.slice(eq + 1).trim());
	}
	for (const [name, value] of Object.entries(overrides)) {
		if (value) pairs.set(name, value);
	}
	if (pairs.size === 0) return null;
	return [...pairs].map(([name, value]) => `${name}=${value}`).join('; ');
}
