<script lang="ts">
	import { page } from '$app/stores';
	import { goto, invalidateAll } from '$app/navigation';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';

	interface Props {
		children?: import('svelte').Snippet;
	}
	let { children }: Props = $props();

	const steps = ['profile', 'bgg-import', 'find-friends', 'add-game'];
	const currentStep = $derived(
		steps.findIndex((s) => $page.url.pathname.includes(s))
	);
	const showSteps = $derived(currentStep >= 0 || $page.url.pathname.includes('welcome'));

	let skipping = $state(false);

	async function handleSkip() {
		if (skipping) return;
		skipping = true;
		try {
			const updatedUser = await usersApi.updateMe({ onboardingCompleted: true });
			setUser(updatedUser);
			await invalidateAll();
			goto('/');
		} catch (err) {
			console.error('Failed to skip onboarding:', err);
			window.location.href = '/';
		} finally {
			skipping = false;
		}
	}
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
			<button 
				onclick={handleSkip} 
				class="text-sm font-label font-bold text-on-surface-variant hover:text-primary transition-colors"
			>
				Skip
			</button>
		{/if}
	</header>

	<main class="flex-1 px-6 pb-12 max-w-lg mx-auto w-full">
		{@render children?.()}
	</main>
</div>

