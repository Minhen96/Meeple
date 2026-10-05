<script lang="ts">
	// Onboarding progress dots (SCREENS_AND_STATES section 3.1): one dot per step, current filled.
	import { m } from '$lib/i18n';

	interface Props {
		total: number;
		/** 1-based current step. */
		current: number;
	}

	let { total, current }: Props = $props();
	const dots = $derived(Array.from({ length: total }, (_, i) => i + 1));
</script>

<div
	class="flex items-center gap-2"
	role="progressbar"
	aria-valuemin={1}
	aria-valuemax={total}
	aria-valuenow={current}
	aria-label={m('account.onboarding.progress', { current, total })}
>
	{#each dots as step (step)}
		<span
			class="h-2 rounded-full transition-all duration-300 {step === current
				? 'w-6 bg-primary'
				: step < current
					? 'w-2 bg-primary/60'
					: 'w-2 bg-surface-container-highest'}"
		></span>
	{/each}
</div>
