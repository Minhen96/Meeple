import { redirect } from '@sveltejs/kit';
import {
	ACCESS_TOKEN_COOKIE,
	REFRESH_TOKEN_COOKIE,
	fetchMe,
	refreshSession
} from '$lib/api/server';
import type { User } from '$lib/types';
import type { LayoutServerLoad } from './$types';

const PUBLIC_PREFIXES = ['/auth', '/onboarding'];

export const load: LayoutServerLoad = async ({ cookies, url, fetch, locals }) => {
	const isPublic = PUBLIC_PREFIXES.some((p) => url.pathname.startsWith(p));
	const accessToken = cookies.get(ACCESS_TOKEN_COOKIE);
	const refreshToken = cookies.get(REFRESH_TOKEN_COOKIE);
	const loginRedirect = `/auth/login?redirect=${encodeURIComponent(url.pathname)}`;

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
		if (refreshed) {
			// Propagate the rotated cookies to the browser, preserving the
			// backend's attributes, so browser and server stay in sync.
			for (const c of refreshed.cookies) {
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

			// Later server fetches in this request (handleFetch) use the new tokens.
			if (refreshed.accessToken) locals.accessToken = refreshed.accessToken;
			if (refreshed.refreshToken) locals.refreshToken = refreshed.refreshToken;

			// The refresh response is not a full User — load the real profile.
			if (refreshed.accessToken) {
				user = await fetchMe(fetch, refreshed.accessToken);
			}
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
