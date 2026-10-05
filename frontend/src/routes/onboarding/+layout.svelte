<script lang="ts">
	// Onboarding shell (SCREENS_AND_STATES section 3.1): progress dots for steps 2–5 and "Skip",
	// which moves to the next step and finishes onboarding after the last one.
	import { goto, invalidateAll } from '$app/navigation';
	import { page } from '$app/state';
	import StepDots from '$lib/components/ui/StepDots.svelte';
	import { usersApi } from '$lib/api/users';
	import { m } from '$lib/i18n';
	import { setUser } from '$lib/stores/auth';
	import { ONBOARDING_STEPS, nextStepPath, stepNumber } from './onboarding';

	interface Props {
		children?: import('svelte').Snippet;
	}
	let { children }: Props = $props();

	const current = $derived(stepNumber(page.url.pathname));
	let skipping = $state(false);

	async function finish() {
		try {
			const updatedUser = await usersApi.updateMe({ onboardingCompleted: true });
			setUser(updatedUser);
			await invalidateAll();
			await goto('/');
		} catch {
			window.location.href = '/';
		}
	}

	async function handleSkip() {
		if (skipping) return;
		const next = nextStepPath(page.url.pathname);
		if (next) {
			void goto(next);
			return;
		}
		skipping = true;
		try {
			await finish();
		} finally {
			skipping = false;
		}
	}
</script>

<div class="min-h-screen bg-background flex flex-col">
	<header class="flex items-center justify-between px-6 py-4 max-w-lg mx-auto w-full">
		{#if current !== null}
			<StepDots total={ONBOARDING_STEPS.length} {current} />
			<button
				onclick={handleSkip}
				disabled={skipping}
				class="text-sm font-label font-bold text-on-surface-variant hover:text-primary transition-colors disabled:opacity-50"
			>
				{m('common.skip')}
			</button>
		{/if}
	</header>

	<main class="flex-1 px-6 pb-12 max-w-lg mx-auto w-full">
		{@render children?.()}
	</main>
</div>
