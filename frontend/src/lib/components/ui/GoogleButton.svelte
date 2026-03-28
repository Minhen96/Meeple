<script lang="ts">
	import { onMount } from 'svelte';
	import { api, ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';

	interface Props {
		redirectTo?: string;
		onError?: (message: string) => void;
	}
	let { redirectTo = '/', onError }: Props = $props();

	const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string;
	let container: HTMLDivElement;

	onMount(() => {
		if (!clientId || typeof window.google === 'undefined') return;

		window.google.accounts.id.initialize({
			client_id: clientId,
			callback: async (response: { credential: string }) => {
				try {
					await api.post('/api/v1/auth/google', { idToken: response.credential });
					goto(redirectTo);
				} catch (err) {
					const message =
						err instanceof ApiRequestError ? err.message : 'Google sign-in failed. Try again.';
					onError?.(message);
				}
			}
		});

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
