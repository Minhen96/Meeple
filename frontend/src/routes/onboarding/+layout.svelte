<script lang="ts">
	// Onboarding shell (SCREENS_AND_STATES section 3.1): progress dots for steps 2–5 and "Skip",
	// which moves to the next step and finishes onboarding after the last one.
	import { goto, invalidateAll } from '$app/navigation';
	import { page } from '$app/state';
	import StepDots from '$lib/components/ui/StepDots.svelte';
	import { usersApi } from '$lib/api/users';
	import { m } from '$lib/i18n';
	import { setUser } from '$lib/stores/auth';
	import { ONBOARDING_STEPS, isWideStep, nextStepPath, stepNumber } from './onboarding';

	interface Props {
		children?: import('svelte').Snippet;
	}
	let { children }: Props = $props();

	const current = $derived(stepNumber(page.url.pathname));
	const wide = $derived(isWideStep(page.url.pathname));
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

<!-- Phones: full-screen steps. md+ (SCREENS_AND_STATES section 16): the same steps in a centred
     card on the warm auth backdrop. -->
<div class="min-h-screen bg-background md:bg-auth-backdrop flex flex-col md:items-center md:justify-center md:px-8 md:py-12">
	<div
		class="flex-1 md:flex-none flex flex-col w-full {wide
			? 'md:max-w-3xl lg:max-w-4xl'
			: 'md:max-w-xl'} md:bg-surface-container-lowest md:rounded-[2rem] md:shadow-[0_12px_32px_rgba(0,0,0,0.06)] md:py-6"
	>
		<header
			class="{current === null
				? 'md:hidden'
				: ''} flex items-center justify-between px-6 md:px-10 py-4 max-w-lg md:max-w-none mx-auto w-full"
		>
			{#if current !== null}
				<StepDots total={ONBOARDING_STEPS.length} {current} />
				<button
					onclick={handleSkip}
					disabled={skipping}
					class="text-sm font-label font-bold text-on-surface-variant hover:text-primary transition-colors disabled:opacity-50 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
				>
					{m('common.skip')}
				</button>
			{/if}
		</header>

		<main class="flex-1 px-6 md:px-10 pb-12 md:pb-6 max-w-lg md:max-w-none mx-auto w-full">
			{@render children?.()}
		</main>
	</div>
</div>
