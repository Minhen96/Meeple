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

	// Game detail page gets no AppBar — floating back button only
	const isGameDetail = $derived(/^\/library\/[^/]+$/.test($page.url.pathname));

	let fabOpen = $state(false);

	const fabActions = [
		{ icon: 'sports_esports', label: 'Log Play',     action: () => goto('/log-play') },
		{ icon: 'event',          label: 'Create Event', action: () => goto('/events/create') },
		{ icon: 'add_photo_alternate', label: 'Create Post', action: () => goto('/posts/create') },
	];

	function handleAction(fn: () => void) {
		fabOpen = false;
		fn();
	}
</script>

{#if !isGameDetail}
	<AppBar showBack={isDetailPage} />
{/if}

<main class="{isGameDetail ? '' : 'pt-16'} px-4 max-w-lg mx-auto pb-32">
	{@render children?.()}
</main>

<!-- Floating back button on game detail pages -->
{#if isGameDetail}
	<button
		onclick={() => history.back()}
		class="fixed top-4 left-4 z-50 w-10 h-10 rounded-full bg-black/30 backdrop-blur-md text-white flex items-center justify-center shadow-md"
		aria-label="Go back"
	>
		<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	</button>
{/if}

<!-- FAB backdrop -->
{#if fabOpen}
	<button
		class="fixed inset-0 z-40"
		onclick={() => { fabOpen = false; }}
		aria-label="Close menu"
	></button>
{/if}

<!-- Floating Action Button -->
<div class="fixed bottom-24 right-6 z-50 flex flex-col items-end gap-3">
	<!-- Mini action buttons (shown when open) -->
	{#if fabOpen}
		{#each fabActions as item}
			<button
				onclick={() => handleAction(item.action)}
				class="flex items-center gap-2 pr-3 pl-2 py-2 rounded-full bg-surface-container-highest text-on-surface shadow-md text-sm font-bold transition-all"
			>
				<span class="w-8 h-8 rounded-full bg-secondary-container text-on-secondary-container flex items-center justify-center">
					<span class="material-symbols-outlined text-[18px]">{item.icon}</span>
				</span>
				{item.label}
			</button>
		{/each}
	{/if}

	<!-- Main FAB -->
	<button
		onclick={() => { fabOpen = !fabOpen; }}
		class="w-14 h-14 bg-primary text-on-primary rounded-full shadow-[0_8px_24px_rgba(137,81,0,0.35)] flex items-center justify-center transition-all duration-200 {fabOpen ? 'rotate-45' : ''}"
		aria-label="Create"
	>
		<span class="material-symbols-outlined text-2xl">add</span>
	</button>
</div>

<BottomNav />
