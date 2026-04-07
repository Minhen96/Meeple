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
	let user = null;

	// 1. Try with access token if it exists
	if (accessToken) {
		try {
			const res = await fetch(`${apiUrl}/api/v1/users/me`, {
				headers: { 'Authorization': `Bearer ${accessToken}` }
			});
			if (res.ok) {
				const body = await res.json();
				user = body.data ? body.data : body;
			}
		} catch (e) {
			// ignore for now, will try refresh
		}
	}

	// 2. If no user yet, but we have a refresh token, try to refresh
	if (!user && refreshToken) {
		try {
			const res = await fetch(`${apiUrl}/api/v1/auth/refresh`, {
				method: 'POST',
				headers: { 'Cookie': `refresh_token=${refreshToken}` }
			});

			if (res.ok) {
				const body = await res.json();
				user = body.data ? body.data : body;
			}
		} catch (e) {
			// refresh failed
		}
	}

	// 3. Final check and redirect logic
	if (!user) {
		if (!isPublic) {
			throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
		}
		return { user: null };
	}

	if (!user.onboardingCompleted && !url.pathname.startsWith('/onboarding')) {
		throw redirect(302, '/onboarding/welcome');
	}

	return { user };
};
