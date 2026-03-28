import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

const PUBLIC_PREFIXES = ['/auth', '/onboarding'];

export const load: LayoutServerLoad = async ({ cookies, url, fetch }) => {
	const isPublic = PUBLIC_PREFIXES.some((p) => url.pathname.startsWith(p));
	const accessToken = cookies.get('access_token');

	if (!accessToken) {
		if (!isPublic) {
			throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
		}
		return { user: null };
	}

	try {
		const apiUrl = import.meta.env.VITE_API_URL as string;
		const res = await fetch(`${apiUrl}/api/v1/users/me`, {
			headers: { Cookie: `access_token=${accessToken}` }
		});

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
		if (e instanceof Response) throw e; // rethrow SvelteKit redirects
		if (!isPublic) {
			throw redirect(302, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
		}
		return { user: null };
	}
};
