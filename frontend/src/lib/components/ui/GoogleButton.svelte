<script module lang="ts">
	// Module-level vars: updated on every mount so the once-initialized
	// GSI callback always uses the current component's props.
	let gsiInitialized = false;
	let currentOnError: ((msg: string) => void) | undefined;
	let currentOnAccountDeleted: ((credential: string) => void) | undefined;
	let currentRedirectTo = '/';
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { authApi } from '$lib/api/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { m } from '$lib/i18n';
	import { safeRedirectPath } from '$lib/utils/redirect';

	interface Props {
		onError?: (message: string) => void;
		/**
		 * The Google account belongs to a Meeple account deleted less than 30 days ago; receives
		 * the Google credential so the page can offer reactivation with it.
		 */
		onAccountDeleted?: (credential: string) => void;
		/** Same-origin path to open after sign-in; validated again here. */
		redirectTo?: string;
	}
	let { onError, onAccountDeleted, redirectTo = '/' }: Props = $props();

	const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string;

	function googleErrorMessage(err: unknown): string {
		if (!(err instanceof ApiRequestError)) return m('account.google.failed');
		switch (err.code) {
			case 'GOOGLE_EMAIL_NOT_VERIFIED':
				return m('account.google.emailNotVerified');
			case 'GOOGLE_ACCOUNT_CONFLICT':
				return m('account.google.conflict');
		}
		if (err.status === 429) return m('errors.rateLimited');
		return m('account.google.failed');
	}
	let container: HTMLDivElement;

	onMount(() => {
		if (!clientId) return;

		// Keep module-level refs current for this mount
		currentOnError = onError;
		currentOnAccountDeleted = onAccountDeleted;
		currentRedirectTo = safeRedirectPath(redirectTo);

		function initGSI() {
			if (typeof window.google === 'undefined' || !window.google.accounts) {
				// Retry in 100ms if SDK is still loading
				setTimeout(initGSI, 100);
				return;
			}

			if (!gsiInitialized) {
				gsiInitialized = true;
				window.google.accounts.id.initialize({
					client_id: clientId,
					callback: async (response: { credential: string }) => {
						try {
							await authApi.googleLogin(response.credential);
							window.location.href = currentRedirectTo;
						} catch (err) {
							if (
								err instanceof ApiRequestError &&
								err.code === 'ACCOUNT_DELETED' &&
								currentOnAccountDeleted
							) {
								currentOnAccountDeleted(response.credential);
								return;
							}
							currentOnError?.(googleErrorMessage(err));
						}
					}
				});
			}

			window.google.accounts.id.renderButton(container, {
				theme: 'outline',
				size: 'large',
				width: container.offsetWidth || 360,
				text: 'continue_with',
				shape: 'rectangular'
			});
		}

		initGSI();
	});
</script>

<div bind:this={container} class="w-full"></div>
