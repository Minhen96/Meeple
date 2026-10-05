<script lang="ts">
	import '../app.css';
	import { Toaster } from 'svelte-sonner';
	import { setUser } from '$lib/stores/auth';
	import { connectWS, disconnectWS } from '$lib/stores/websocket';
	import type { User } from '$lib/types';

	interface Props {
		data: { user: User | null };
		children?: import('svelte').Snippet;
	}

	let { data, children }: Props = $props();

	$effect(() => {
		setUser(data.user);
	});

	// Depend on the user id only, so profile edits / layout re-runs that
	// produce a new user object don't tear down and rebuild the socket.
	const userId = $derived(data.user?.id ?? null);

	$effect(() => {
		if (userId) {
			// Auth via the access_token cookie sent with the WebSocket upgrade.
			connectWS();
			return () => disconnectWS();
		}
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
