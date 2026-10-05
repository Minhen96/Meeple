import { error, redirect } from '@sveltejs/kit';
import { ApiRequestError } from './client';

/**
 * Convert an API failure inside a `load` function into the right SvelteKit
 * outcome. Safe on both server and client (never calls goto()):
 * - 401 → redirect to login (session missing/expired)
 * - other 4xx → 404 with `notFoundMessage`
 * - anything else → 500
 */
export function throwLoadError(err: unknown, url: URL, notFoundMessage = 'Not found'): never {
	if (err instanceof ApiRequestError) {
		if (err.status === 401) {
			redirect(303, `/auth/login?redirect=${encodeURIComponent(url.pathname)}`);
		}
		if (err.status >= 400 && err.status < 500) {
			error(404, notFoundMessage);
		}
	}
	error(500, 'Something went wrong. Please try again.');
}
