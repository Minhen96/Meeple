// See https://svelte.dev/docs/kit/types#app.d.ts
declare global {
	namespace App {
		interface Locals {
			/** Access token issued by a server-side refresh during this request. */
			accessToken?: string;
			/** Rotated refresh token issued by a server-side refresh during this request. */
			refreshToken?: string;
		}
	}
}

export {};
