<script lang="ts">
	import { page } from '$app/stores';

	interface Props {
		children?: import('svelte').Snippet;
	}
	let { children }: Props = $props();

	const steps = ['profile', 'bgg-import', 'find-friends', 'add-game'];
	const currentStep = $derived(
		steps.findIndex((s) => $page.url.pathname.includes(s))
	);
	const showSteps = $derived(currentStep >= 0);
</script>

<div class="min-h-screen bg-background flex flex-col">
	<!-- Header with step indicator -->
	<header class="flex items-center justify-between px-6 py-4 max-w-lg mx-auto w-full">
		{#if showSteps}
			<div class="flex gap-2">
				{#each steps as _, i}
					<div
						class="w-2 h-2 rounded-full transition-colors {i <= currentStep ? 'bg-primary' : 'bg-surface-container-highest'}"
					></div>
				{/each}
			</div>
		{:else}
			<div></div>
		{/if}

		{#if showSteps}
			<a href="/onboarding/welcome" class="text-sm font-label font-bold text-on-surface-variant">
				Skip
			</a>
		{/if}
	</header>

	<main class="flex-1 px-6 pb-12 max-w-lg mx-auto w-full">
		{@render children?.()}
	</main>
</div>
