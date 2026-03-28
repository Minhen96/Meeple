<script lang="ts">
	import '../app.css';
	import { Toaster } from 'svelte-sonner';
	import { setUser } from '$lib/stores/auth';
	import { connectWS } from '$lib/stores/websocket';

	interface Props {
		data: { user: import('$lib/types').User | null };
		children?: import('svelte').Snippet;
	}

	let { data, children }: Props = $props();

	$effect(() => {
		setUser(data.user);
		// WebSocket connection is set up here when user is authenticated.
		// The access token is managed by the httpOnly cookie — the WS store
		// reads it via the STOMP connect header after a separate token fetch
		// in Phase 2. For now, WS is wired but not auto-connected on load.
	});
</script>

{@render children?.()}

<Toaster
	position="bottom-center"
	toastOptions={{
		classes: {
			toast: 'font-body rounded-xl',
			title: 'font-semibold'
		}
	}}
/>
