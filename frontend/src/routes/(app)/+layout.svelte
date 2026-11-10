<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { afterNavigate, beforeNavigate, goto } from '$app/navigation';
	import { page } from '$app/state';
	import AppBar from '$lib/components/layout/AppBar.svelte';
	import BottomNav from '$lib/components/layout/BottomNav.svelte';
	import Sidebar from '$lib/components/layout/Sidebar.svelte';
	import {
		hasInAppHistory,
		logicalParent,
		recordNavigation,
		rememberScroll,
		savedScroll
	} from '$lib/components/layout/navigation';
	import { getLocale, isLocale, m, setLocale } from '$lib/i18n';
	import { notificationsApi } from '$lib/api/notifications';
	import { setUnreadCount } from '$lib/stores/notifications';
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
			/^\/events\/[^/]+\/edit\/?$/.test(pathname) ||
			pathname.startsWith('/profile/friends') ||
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

	// Badge only: the list itself belongs to the notifications screen (and the WebSocket), so a
	// cold load straight onto /notifications never has its first page overwritten from here.
	onMount(async () => {
		try {
			setUnreadCount(await notificationsApi.getUnreadCount());
		} catch {
			// non-critical — the badge falls back to the loaded items
		}
	});
</script>

<!-- md+: rail / sidebar on every app screen (replaces the bottom nav and the app bar's actions) -->
<Sidebar />

{#if !isImmersiveRoute}
	<AppBar showBack={isDetailPage} />
{/if}

<!-- Content column (SCREENS_AND_STATES section 16): max-w-lg on phones, max-w-xl beside the md
     rail, max-w-2xl beside the lg sidebar. A page wrapped in <PageContainer> chooses its own width
     from md up (the :has() variant drops this default). -->
<div class="md:pl-rail lg:pl-sidebar">
	<main
		class="{isImmersiveRoute
			? 'pt-4'
			: isDetailPage
				? 'pt-16'
				: 'pt-16 md:pt-8'} px-4 md:px-8 w-full max-w-lg md:max-w-xl lg:max-w-2xl md:[&:has([data-page-container])]:max-w-none mx-auto pb-32 md:pb-12"
	>
		{@render children?.()}
	</main>
</div>

<!-- Floating back button on the immersive game detail -->
{#if isGameDetail}
	<button
		onclick={back}
		class="fixed top-4 left-4 md:ml-rail lg:ml-sidebar z-50 w-10 h-10 rounded-full bg-black/30 backdrop-blur-md text-white flex items-center justify-center shadow-md"
		aria-label={m('common.back')}
	>
		<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	</button>
{/if}

{#if !isImmersiveRoute}
	<BottomNav />
{/if}
