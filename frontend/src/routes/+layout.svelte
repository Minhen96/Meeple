<script lang="ts">
	import '../app.css';
	import { untrack } from 'svelte';
	import { Toaster } from 'svelte-sonner';
	import OfflineBanner from '$lib/components/layout/OfflineBanner.svelte';
	import { locale, setLocale, type Locale } from '$lib/i18n';
	import { identifyUser } from '$lib/observability';
	import { setUser } from '$lib/stores/auth';
	import { connectWS, disconnectWS } from '$lib/stores/websocket';
	import type { User } from '$lib/types';

	interface Props {
		data: { user: User | null; locale: Locale };
		children?: import('svelte').Snippet;
	}

	let { data, children }: Props = $props();

	// Apply the request's locale before any child renders (SSR and hydration), then follow
	// changes from later server loads (for example after the `lang` cookie changed).
	setLocale(untrack(() => data.locale));
	$effect.pre(() => {
		setLocale(data.locale);
	});

	$effect(() => {
		setUser(data.user);
	});

	// Depend on the user id only, so profile edits / layout re-runs that
	// produce a new user object don't tear down and rebuild the socket.
	const userId = $derived(data.user?.id ?? null);

	// Error tracking / analytics identity: the user id only, never email (no-op if unconfigured).
	$effect(() => {
		identifyUser(userId);
	});

	$effect(() => {
		if (userId) {
			// Auth via the access_token cookie sent with the WebSocket upgrade.
			connectWS();
			return () => disconnectWS();
		}
	});
</script>

<OfflineBanner />

<!-- m() is not reactive on its own: re-render the page when the locale changes. -->
{#key $locale}
	{@render children?.()}
{/key}

<Toaster
	position="bottom-center"
	toastOptions={{
		classes: {
			toast: 'font-body rounded-xl',
			title: 'font-semibold'
		}
	}}
/>
