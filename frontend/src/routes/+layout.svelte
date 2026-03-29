<script lang="ts">
	import '../app.css';
	import { Toaster } from 'svelte-sonner';
	import { setUser } from '$lib/stores/auth';
	import { connectWS, disconnectWS } from '$lib/stores/websocket';

	interface Props {
		data: { user: import('$lib/types').User | null };
		children?: import('svelte').Snippet;
	}

	let { data, children }: Props = $props();

	$effect(() => {
		setUser(data.user);
		if (data.user) {
			// Cookie is sent automatically with the WS upgrade request
			// Pass userId so we can subscribe to the right topic
			connectWS(data.user.id, '');
		} else {
			disconnectWS();
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
