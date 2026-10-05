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
				const n = Number(val);
				if (Number.isFinite(n)) cookie.maxAge = n;
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

export interface RefreshResult {
	/** Cookies the backend asked to set (rotated access + refresh tokens). */
	cookies: ParsedSetCookie[];
	accessToken: string | null;
	refreshToken: string | null;
}

/**
 * POST /api/v1/auth/refresh with an explicit refresh token cookie.
 * Returns null if the backend rejected the token or was unreachable.
 */
export async function refreshSession(
	fetchFn: FetchFn,
	refreshToken: string
): Promise<RefreshResult | null> {
	try {
		const res = await fetchFn(`${API_BASE_URL}/api/v1/auth/refresh`, {
			method: 'POST',
			headers: {
				Cookie: `${REFRESH_TOKEN_COOKIE}=${refreshToken}`,
				'Content-Type': 'application/json'
			}
		});
		if (!res.ok) return null;

		const cookies = getSetCookies(res.headers)
			.map(parseSetCookie)
			.filter((c): c is ParsedSetCookie => c !== null);

		const find = (name: string) => cookies.find((c) => c.name === name)?.value || null;
		return {
			cookies,
			accessToken: find(ACCESS_TOKEN_COOKIE),
			refreshToken: find(REFRESH_TOKEN_COOKIE)
		};
	} catch {
		return null;
	}
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
