// See https://svelte.dev/docs/kit/types#app.d.ts
import type { Locale } from '$lib/i18n';

declare global {
	namespace App {
		interface Locals {
			/** Access token issued by a server-side refresh during this request. */
			accessToken?: string;
			/** Rotated refresh token issued by a server-side refresh during this request. */
			refreshToken?: string;
			/** UI locale for this request: `lang` cookie, else Accept-Language (hooks.server.ts). */
			locale?: Locale;
		}
	}

	/** Optional, build-time public config. Unset disables the feature (see lib/observability.ts). */
	interface ImportMetaEnv {
		readonly VITE_SENTRY_DSN?: string;
		readonly VITE_SENTRY_ENVIRONMENT?: string;
		readonly VITE_POSTHOG_KEY?: string;
		readonly VITE_POSTHOG_HOST?: string;
	}
}

export {};
