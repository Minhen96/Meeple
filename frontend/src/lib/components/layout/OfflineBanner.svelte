<script lang="ts">
	// Offline banner (SCREENS_AND_STATES section 14.4): a slim bar pinned below the app bar while
	// the browser is offline, then a brief "Back online" flash when the connection returns.
	import { onMount } from 'svelte';
	import { slide } from 'svelte/transition';
	import { m } from '$lib/i18n';

	const BACK_ONLINE_FLASH_MS = 2500;

	// Assume online during SSR; the real state is read on mount.
	let online = $state(true);
	let showBackOnline = $state(false);
	let flashTimer: ReturnType<typeof setTimeout> | undefined;

	onMount(() => {
		online = navigator.onLine;
		const setOnline = () => {
			if (!online) {
				showBackOnline = true;
				clearTimeout(flashTimer);
				flashTimer = setTimeout(() => (showBackOnline = false), BACK_ONLINE_FLASH_MS);
			}
			online = true;
		};
		const setOffline = () => {
			online = false;
			showBackOnline = false;
			clearTimeout(flashTimer);
		};
		window.addEventListener('online', setOnline);
		window.addEventListener('offline', setOffline);
		return () => {
			clearTimeout(flashTimer);
			window.removeEventListener('online', setOnline);
			window.removeEventListener('offline', setOffline);
		};
	});
</script>

{#if !online || showBackOnline}
	<div
		role="status"
		aria-live="polite"
		transition:slide={{ duration: 200 }}
		class="fixed inset-x-0 top-[calc(env(safe-area-inset-top)+4rem)] z-[60] h-8 flex items-center justify-center gap-1.5 text-xs font-label font-bold {online
			? 'bg-tertiary text-on-tertiary'
			: 'bg-on-surface text-inverse-on-surface'}"
	>
		<span class="material-symbols-outlined text-[16px]" aria-hidden="true">
			{online ? 'wifi' : 'wifi_off'}
		</span>
		{online ? m('common.backOnline') : m('common.noInternet')}
	</div>
{/if}
