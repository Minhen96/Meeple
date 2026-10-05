import type { Handle, HandleFetch } from '@sveltejs/kit';
import {
	ACCESS_TOKEN_COOKIE,
	API_ORIGIN,
	REFRESH_TOKEN_COOKIE,
	buildForwardedCookieHeader
} from '$lib/api/server';
import { LOCALE_COOKIE, detectLocale, isLocale } from '$lib/i18n';

export const handle: Handle = async ({ event, resolve }) => {
	const cookieLocale = event.cookies.get(LOCALE_COOKIE);
	const locale = isLocale(cookieLocale)
		? cookieLocale
		: detectLocale(event.request.headers.get('accept-language'));
	event.locals.locale = locale;

	return resolve(event, {
		transformPageChunk: ({ html }) => html.replace('%lang%', locale)
	});
};

/**
 * SvelteKit only forwards cookies to its own origin (or subdomains). The
 * backend API lives on a different origin, so during SSR we forward the
 * browser's cookie header ourselves — with tokens rotated by a server-side
 * refresh earlier in this request (event.locals) taking precedence.
 */
export const handleFetch: HandleFetch = async ({ event, request, fetch }) => {
	if (API_ORIGIN && new URL(request.url).origin === API_ORIGIN) {
		// Respect an explicit Cookie header (e.g. the refresh call in +layout.server.ts).
		if (!request.headers.has('cookie')) {
			const cookie = buildForwardedCookieHeader(event.request.headers.get('cookie'), {
				[ACCESS_TOKEN_COOKIE]: event.locals.accessToken,
				[REFRESH_TOKEN_COOKIE]: event.locals.refreshToken
			});
			if (cookie) request.headers.set('cookie', cookie);
		}
		if (event.locals.accessToken && !request.headers.has('authorization')) {
			request.headers.set('authorization', `Bearer ${event.locals.accessToken}`);
		}
	}
	return fetch(request);
};
