<script lang="ts">
	import AppBar from '$lib/components/layout/AppBar.svelte';
	import BottomNav from '$lib/components/layout/BottomNav.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();

	// Detail pages show a back button instead of just title
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

<!-- Floating Create Button -->
<div class="fixed bottom-24 right-6 z-50">
	<button
		onclick={() => goto('/posts/create')}
		class="w-14 h-14 bg-primary text-on-primary rounded-full shadow-[0_8px_24px_rgba(137,81,0,0.35)] flex items-center justify-center hover:scale-110 active:scale-90 transition-all duration-150"
		aria-label="Create"
	>
		<span class="material-symbols-outlined text-2xl">add</span>
	</button>
</div>

<BottomNav />
