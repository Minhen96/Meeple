<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { afterNavigate, beforeNavigate, goto } from '$app/navigation';
	import { page } from '$app/state';
	import AppBar from '$lib/components/layout/AppBar.svelte';
	import BottomNav from '$lib/components/layout/BottomNav.svelte';
	import {
		hasInAppHistory,
		logicalParent,
		recordNavigation,
		rememberScroll,
		savedScroll
	} from '$lib/components/layout/navigation';
	import { getLocale, isLocale, m, setLocale } from '$lib/i18n';
	import { notificationsApi } from '$lib/api/notifications';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/stores/auth';

	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();

	const pathname = $derived(page.url.pathname);

	// Detail pages show a back button instead of the logo
	const detailRoutes = ['/library/', '/events/', '/posts/', '/profile/', '/settings', '/admin', '/search'];
	const isDetailPage = $derived(
		detailRoutes.some((r) =>
			r.endsWith('/') ? pathname.startsWith(r) && pathname !== r.slice(0, -1) : pathname.startsWith(r)
		)
	);

	// Pages that hide the global app bar and bottom nav for a focused, immersive screen
	const isImmersiveRoute = $derived(
		/^\/library\/[^/]+\/?$/.test(pathname) ||
			/^\/events\/[^/]+\/?$/.test(pathname) ||
			/^\/posts\/[^/]+\/?$/.test(pathname) ||
			pathname.startsWith('/notifications') ||
			pathname.startsWith('/settings') ||
			pathname.startsWith('/admin') ||
			pathname.startsWith('/log-play') ||
			pathname.startsWith('/events/create') ||
			pathname.startsWith('/posts/create')
	);
	const isGameDetail = $derived(/^\/library\/[^/]+\/?$/.test(pathname));

	// The account's language wins over the browser's once the user is known (settings switcher
	// stores both); persisting writes the `lang` cookie so SSR renders in it next time.
	$effect(() => {
		const preferred = $currentUser?.preferredLanguage;
		if (isLocale(preferred) && preferred !== getLocale()) {
			setLocale(preferred, { persist: true });
		}
	});

	// Per-tab scroll memory (SCREENS_AND_STATES section 15.4) and in-app history for back.
	beforeNavigate(({ from }) => {
		if (from?.url) rememberScroll(from.url.pathname, window.scrollY);
	});
	afterNavigate(async ({ type, to }) => {
		recordNavigation(type);
		if (type !== 'link' || !to?.url) return;
		const saved = savedScroll(to.url.pathname);
		if (saved !== null) {
			await tick();
			window.scrollTo({ top: saved });
		}
	});

	function back() {
		if (hasInAppHistory()) history.back();
		else void goto(logicalParent(pathname));
	}

	onMount(async () => {
		try {
			const res = await notificationsApi.getAll();
			notifications.set(res?.data ?? []);
		} catch {
			// non-critical — badge stays at 0
		}
	});
</script>

{#if !isImmersiveRoute}
	<AppBar showBack={isDetailPage} />
{/if}

<main class="{isImmersiveRoute ? 'pt-4' : 'pt-16'} px-4 max-w-lg mx-auto pb-32">
	{@render children?.()}
</main>

<!-- Floating back button on the immersive game detail -->
{#if isGameDetail}
	<button
		onclick={back}
		class="fixed top-4 left-4 z-50 w-10 h-10 rounded-full bg-black/30 backdrop-blur-md text-white flex items-center justify-center shadow-md"
		aria-label={m('common.back')}
	>
		<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	</button>
{/if}

{#if !isImmersiveRoute}
	<BottomNav />
{/if}
