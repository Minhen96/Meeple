<script lang="ts">
	import AppBar from '$lib/components/layout/AppBar.svelte';
	import BottomNav from '$lib/components/layout/BottomNav.svelte';
	import { page } from '$app/stores';

	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();

	// Detail pages show a back button instead of search
	const detailRoutes = ['/library/', '/events/', '/posts/', '/profile/'];
	const isDetailPage = $derived(
		detailRoutes.some(
			(r) => $page.url.pathname.startsWith(r) && $page.url.pathname !== r.slice(0, -1)
		)
	);
</script>

<AppBar showBack={isDetailPage} />

<main class="pt-24 px-4 max-w-lg mx-auto pb-32">
	{@render children?.()}
</main>

<BottomNav />
