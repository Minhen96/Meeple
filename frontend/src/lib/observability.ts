/**
 * Client-side error tracking (Sentry) and product analytics (PostHog), both env-gated:
 * nothing is loaded or sent unless VITE_SENTRY_DSN / VITE_POSTHOG_KEY are set at build time.
 * The SDKs are imported dynamically so builds without the keys do not ship them.
 *
 * Only the user's id is ever attached: no email, username or other PII (CLAUDE.md).
 */
import type { PostHog } from 'posthog-js';

type SentrySdk = typeof import('@sentry/sveltekit');

let sentry: SentrySdk | null = null;
let posthog: PostHog | null = null;
let initStarted = false;
/** Last identity requested; `undefined` until identifyUser is first called. */
let currentUserId: string | null | undefined;

/** Load and start the configured SDKs. Call once from hooks.client.ts; safe to call again. */
export async function initObservability(): Promise<void> {
	if (initStarted || typeof window === 'undefined') return;
	initStarted = true;

	const sentryDsn = import.meta.env.VITE_SENTRY_DSN;
	const posthogKey = import.meta.env.VITE_POSTHOG_KEY;
	const tasks: Promise<void>[] = [];

	if (sentryDsn) {
		tasks.push(
			import('@sentry/sveltekit').then((sdk) => {
				sdk.init({
					dsn: sentryDsn,
					environment: import.meta.env.VITE_SENTRY_ENVIRONMENT || import.meta.env.MODE,
					tracesSampleRate: 0,
					// Successor of sendDefaultPii: false. No automatic user info (IP), cookies,
					// headers, bodies or query params (reset/verify links carry tokens).
					dataCollection: {
						userInfo: false,
						cookies: false,
						httpHeaders: false,
						httpBodies: [],
						urlQueryParams: false
					}
				});
				sentry = sdk;
			})
		);
	}

	if (posthogKey) {
		tasks.push(
			import('posthog-js').then(({ default: client }) => {
				client.init(posthogKey, {
					api_host: import.meta.env.VITE_POSTHOG_HOST || 'https://us.i.posthog.com',
					person_profiles: 'identified_only',
					persistence: 'memory',
					capture_pageview: false
				});
				posthog = client;
			})
		);
	}

	const results = await Promise.allSettled(tasks);
	for (const result of results) {
		if (result.status === 'rejected')
			console.warn('Observability SDK failed to load', result.reason);
	}
	// Apply an identity that was set while the SDKs were still loading.
	if (currentUserId !== undefined) applyIdentity(currentUserId);
}

function applyIdentity(userId: string | null): void {
	if (userId) {
		sentry?.setUser({ id: userId });
		posthog?.identify(userId);
	} else {
		sentry?.setUser(null);
		posthog?.reset();
	}
}

/** Attach the signed-in user's id to future reports, or clear it on logout (`null`). */
export function identifyUser(userId: string | null): void {
	if (userId === currentUserId) return;
	currentUserId = userId;
	applyIdentity(userId);
}

/** Report an unexpected client error to Sentry (no-op when Sentry is not configured). */
export function captureError(error: unknown): void {
	sentry?.captureException(error);
}

/** Send a product analytics event to PostHog (no-op when PostHog is not configured). */
export function track(event: string, properties?: Record<string, unknown>): void {
	posthog?.capture(event, properties);
}
