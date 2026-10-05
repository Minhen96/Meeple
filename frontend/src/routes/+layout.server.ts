import { redirect, type Cookies } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import {
	ACCESS_TOKEN_COOKIE,
	REFRESH_TOKEN_COOKIE,
	fetchMe,
	refreshSession,
	type ParsedSetCookie
} from '$lib/api/server';
import type { User } from '$lib/types';
import type { LayoutServerLoad } from './$types';

const PUBLIC_PREFIXES = ['/auth', '/onboarding'];

/**
 * Set while we bounce the browser after a 409 REFRESH_RACE, so a second race
 * on the retried request falls through instead of redirecting forever.
 */
const REFRESH_RETRY_COOKIE = 'refresh_race_retry';
const REFRESH_RETRY_MAX_AGE_S = 10;

/** Forward Set-Cookie headers from the backend to the browser, attributes preserved. */
function applyBackendCookies(cookies: Cookies, parsed: ParsedSetCookie[]) {
	for (const c of parsed) {
		cookies.set(c.name, c.value, {
			path: c.path ?? '/',
			domain: c.domain,
			httpOnly: c.httpOnly,
			secure: c.secure,
			sameSite: c.sameSite,
			maxAge: c.maxAge,
			expires: c.expires,
			// Values come straight from Set-Cookie and are already encoded.
			encode: (v) => v
		});
	}
}

/**
 * The refresh token was rejected: make sure the browser stops sending it.
 * Cookies are deleted host-only and for every domain they may have been set
 * with (COOKIE_DOMAIN, or a domain the backend used in its own deletions).
 */
function deleteAuthCookies(cookies: Cookies, backendCookies: ParsedSetCookie[]) {
	const domains = new Set<string | undefined>([undefined]);
	if (env.COOKIE_DOMAIN) domains.add(env.COOKIE_DOMAIN);
	for (const c of backendCookies) if (c.domain) domains.add(c.domain);

	for (const name of [ACCESS_TOKEN_COOKIE, REFRESH_TOKEN_COOKIE]) {
		for (const domain of domains) cookies.delete(name, { path: '/', domain });
	}
}

export const load: LayoutServerLoad = async ({ cookies, url, fetch, locals }) => {
	const isPublic = PUBLIC_PREFIXES.some((p) => url.pathname.startsWith(p));
	const accessToken = cookies.get(ACCESS_TOKEN_COOKIE);
	const refreshToken = cookies.get(REFRESH_TOKEN_COOKIE);
	const loginRedirect = `/auth/login?redirect=${encodeURIComponent(url.pathname + url.search)}`;
	const retriedAfterRace = cookies.get(REFRESH_RETRY_COOKIE) !== undefined;
	if (retriedAfterRace) cookies.delete(REFRESH_RETRY_COOKIE, { path: '/' });

	if (!accessToken && !refreshToken) {
		if (!isPublic) redirect(302, loginRedirect);
		return { user: null };
	}

	let user: User | null = null;

	// 1. Try the current access token.
	if (accessToken) {
		user = await fetchMe(fetch, accessToken);
	}

	// 2. Access token missing/expired: refresh on the server.
	if (!user && refreshToken) {
		const refreshed = await refreshSession(fetch, refreshToken);
		switch (refreshed.kind) {
			case 'refreshed':
				// Propagate the rotated cookies so browser and server stay in sync.
				applyBackendCookies(cookies, refreshed.cookies);

				// Later server fetches in this request (handleFetch) use the new tokens.
				if (refreshed.accessToken) locals.accessToken = refreshed.accessToken;
				if (refreshed.refreshToken) locals.refreshToken = refreshed.refreshToken;

				// The refresh response is not a full User — load the real profile.
				if (refreshed.accessToken) {
					user = await fetchMe(fetch, refreshed.accessToken);
				}
				break;
			case 'race':
				// A concurrent refresh (another tab, a preload, the client) rotated
				// the token first and its response is updating the browser's
				// cookies. Have the browser retry this request with them — once.
				if (!retriedAfterRace) {
					cookies.set(REFRESH_RETRY_COOKIE, '1', {
						path: '/',
						httpOnly: true,
						sameSite: 'lax',
						maxAge: REFRESH_RETRY_MAX_AGE_S
					});
					redirect(307, url.pathname + url.search);
				}
				break;
			case 'rejected':
				applyBackendCookies(cookies, refreshed.cookies);
				deleteAuthCookies(cookies, refreshed.cookies);
				break;
			case 'unavailable':
				applyBackendCookies(cookies, refreshed.cookies);
				break;
		}
	}

	// 3. Final check and redirect logic
	if (!user) {
		if (!isPublic) redirect(302, loginRedirect);
		return { user: null };
	}

	if (!user.onboardingCompleted && !url.pathname.startsWith('/onboarding')) {
		redirect(302, '/onboarding/welcome');
	}

	return { user };
};
