<script module lang="ts">
	// Module-level vars: updated on every mount so the once-initialized
	// GSI callback always uses the current component's props.
	let gsiInitialized = false;
	let currentOnError: ((msg: string) => void) | undefined;
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { api, ApiRequestError } from '$lib/api/client';

	interface Props {
		onError?: (message: string) => void;
	}
	let { onError }: Props = $props();

	const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string;
	let container: HTMLDivElement;

	onMount(() => {
		if (!clientId || typeof window.google === 'undefined') return;

		// Keep module-level refs current for this mount
		currentOnError = onError;

		if (!gsiInitialized) {
			gsiInitialized = true;
			window.google.accounts.id.initialize({
				client_id: clientId,
				callback: async (response: { credential: string }) => {
					try {
						await api.post('/api/v1/auth/google', { idToken: response.credential });
						// Always redirect to home as requested
						window.location.href = '/';
					} catch (err) {
						const message =
							err instanceof ApiRequestError ? err.message : 'Google sign-in failed. Try again.';
						currentOnError?.(message);
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
	});
</script>

<div bind:this={container} class="w-full"></div>
