import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

const API_URL = import.meta.env.VITE_API_URL as string || 'http://localhost:8081';

export const POST: RequestHandler = async ({ cookies, fetch: svelteKitFetch }) => {
	const accessToken = cookies.get('access_token');
	const refreshToken = cookies.get('refresh_token');

	let token = accessToken;

	// If access token missing, try to refresh first
	if (!token && refreshToken) {
		try {
			const refreshRes = await svelteKitFetch(`${API_URL}/api/v1/auth/refresh`, {
				method: 'POST',
				headers: { Cookie: `refresh_token=${refreshToken}` }
			});
			if (refreshRes.ok) {
				token = cookies.get('access_token');
			}
		} catch {
			// continue without refresh
		}
	}

	if (token) {
		try {
			await svelteKitFetch(`${API_URL}/api/v1/users/me`, {
				method: 'PUT',
				headers: {
					Authorization: `Bearer ${token}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ onboardingCompleted: true })
			});
		} catch {
			// ignore error — redirect anyway so user is never stuck
		}
	}

	throw redirect(302, '/');
};
