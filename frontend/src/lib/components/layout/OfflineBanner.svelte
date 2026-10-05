<script lang="ts">
	// Minimal offline indicator mounted once in the root layout. Owned by WP5 (refine there).
	import { onMount } from 'svelte';
	import { m } from '$lib/i18n';

	// Assume online during SSR; the real state is read on mount.
	let online = $state(true);

	onMount(() => {
		online = navigator.onLine;
		const setOnline = () => (online = true);
		const setOffline = () => (online = false);
		window.addEventListener('online', setOnline);
		window.addEventListener('offline', setOffline);
		return () => {
			window.removeEventListener('online', setOnline);
			window.removeEventListener('offline', setOffline);
		};
	});
</script>

{#if !online}
	<div
		role="status"
		aria-live="polite"
		class="fixed inset-x-0 top-0 z-[100] bg-inverse-surface px-4 pb-2 pt-[calc(env(safe-area-inset-top)+0.5rem)] text-center text-sm font-semibold text-inverse-on-surface"
	>
		{m('common.offline')}
	</div>
{/if}
