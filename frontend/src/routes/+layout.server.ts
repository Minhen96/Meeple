import { redirect, isRedirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

const PUBLIC_PREFIXES = ['/auth', '/onboarding'];

export const load: LayoutServerLoad = async ({ cookies, url, fetch }) => {
	const isPublic = PUBLIC_PREFIXES.some((p) => url.pathname.startsWith(p));
	const accessToken = cookies.get('access_token');
	const refreshToken = cookies.get('refresh_token');

	if (!accessToken && !refreshToken) {
		if (!isPublic) {
			throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
		}
		return { user: null };
	}

	const apiUrl = import.meta.env.VITE_API_URL as string;

	if (!accessToken && refreshToken) {
		// Attempt to refresh
		try {
			const res = await fetch(`${apiUrl}/api/v1/auth/refresh`, {
				method: 'POST'
			});

			// If refresh fails and we are not in a public page, redirect to login
			if (!res.ok) {
				if (!isPublic) {
					throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
				}
				return { user: null };
			}
			// SvelteKit's fetch automatically handles 'Set-Cookie' headers and updates the current request's cookies
			// But since we need the newly set accessToken for the next 'me' call, we might need a fallback or re-check.
			// However, usually the backend responds with the user info in the refresh response too.
			const { data: user } = await res.json();
			if (user) {
				if (!user.onboardingCompleted && !url.pathname.startsWith('/onboarding')) {
					throw redirect(302, '/onboarding/welcome');
				}
				return { user };
			}
		} catch (e) {
			if (isRedirect(e)) throw e;
			if (!isPublic) {
				throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
			}
			return { user: null };
		}
	}

	// If we have an access token (either from the start or after a refresh if it was somehow redirected)
	try {
		const res = await fetch(`${apiUrl}/api/v1/users/me`);

		if (!res.ok) {
			if (!isPublic) {
				throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
			}
			return { user: null };
		}

		const { data: user } = await res.json();

		if (!user.onboardingCompleted && !url.pathname.startsWith('/onboarding')) {
			throw redirect(302, '/onboarding/welcome');
		}

		return { user };
	} catch (e) {
		if (isRedirect(e)) throw e;
		if (!isPublic) {
			throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
		}
		return { user: null };
	}
};
