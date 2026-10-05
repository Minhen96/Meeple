<script lang="ts">
	// Five-star rating over the 1–10 personal rating (FEATURES_COMPLETE section 3.3).
	// Interactive when `onrate` is given: tapping a star sends 2/4/6/8/10, tapping the
	// current star clears the rating (0).
	import { m } from '$lib/i18n';
	import { ratingForStarTap, starsFromRating } from './collection';

	interface Props {
		rating: number | null;
		onrate?: (rating: number) => void;
		disabled?: boolean;
		size?: 'sm' | 'md';
	}

	let { rating, onrate, disabled = false, size = 'sm' }: Props = $props();

	const filled = $derived(starsFromRating(rating));
	const iconSize = $derived(size === 'sm' ? 'text-[16px]' : 'text-[24px]');

	function tap(event: MouseEvent, star: number) {
		// Inside card links: rate without navigating
		event.preventDefault();
		event.stopPropagation();
		if (!disabled) onrate?.(ratingForStarTap(star, rating));
	}
</script>

{#if onrate}
	<div class="flex items-center gap-0.5" role="group" aria-label={m('library.rating.label')}>
		{#each [1, 2, 3, 4, 5] as star (star)}
			<button
				type="button"
				onclick={(e) => tap(e, star)}
				{disabled}
				aria-label={m('library.rating.star', { count: star })}
				aria-pressed={star <= filled}
				class="p-0.5 rounded-full transition-transform active:scale-90 disabled:opacity-50 {star <= filled
					? 'text-primary-container'
					: 'text-on-surface-variant/40'}"
			>
				<span class="material-symbols-outlined {iconSize}" class:icon-filled={star <= filled}>star</span>
			</button>
		{/each}
	</div>
{:else if filled > 0}
	<div class="flex items-center gap-0.5 text-primary-container" aria-label={`${filled}/5`}>
		{#each [1, 2, 3, 4, 5] as star (star)}
			<span
				class="material-symbols-outlined {iconSize} {star <= filled ? '' : 'text-on-surface-variant/30'}"
				class:icon-filled={star <= filled}>star</span
			>
		{/each}
	</div>
{/if}
