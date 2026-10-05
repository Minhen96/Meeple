<script module lang="ts">
	// Module-level vars: updated on every mount so the once-initialized
	// GSI callback always uses the current component's props.
	let gsiInitialized = false;
	let currentOnError: ((msg: string) => void) | undefined;
	let currentRedirectTo = '/';
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { api, ApiRequestError } from '$lib/api/client';
	import { safeRedirectPath } from '$lib/utils/redirect';

	interface Props {
		onError?: (message: string) => void;
		/** Same-origin path to open after sign-in; validated again here. */
		redirectTo?: string;
	}
	let { onError, redirectTo = '/' }: Props = $props();

	const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string;

	function googleErrorMessage(err: unknown): string {
		if (!(err instanceof ApiRequestError)) return 'Google sign-in failed. Try again.';
		switch (err.code) {
			case 'GOOGLE_EMAIL_NOT_VERIFIED':
				return 'Your Google email address is not verified. Verify it with Google, then try again.';
			case 'GOOGLE_ACCOUNT_CONFLICT':
				return 'An account with this email already exists. Log in with your password instead.';
		}
		if (err.status === 429) return 'Too many requests, try later.';
		return err.message || 'Google sign-in failed. Try again.';
	}
	let container: HTMLDivElement;

	onMount(() => {
		if (!clientId) return;

		// Keep module-level refs current for this mount
		currentOnError = onError;
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
							await api.post('/api/v1/auth/google', { idToken: response.credential });
							window.location.href = currentRedirectTo;
						} catch (err) {
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
