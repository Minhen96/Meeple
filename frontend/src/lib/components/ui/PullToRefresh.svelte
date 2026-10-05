<script lang="ts">
	// Pull-to-refresh for touch devices (SCREENS_AND_STATES section 14.5). Wrap a page's list:
	// pulling down while the window is scrolled to the top shows a spinner below the app bar and
	// calls `onRefresh` (awaited) once released past the threshold.
	import Spinner from './Spinner.svelte';
	import { m } from '$lib/i18n';
	import { indicatorOffsetClass, pullDistance, pullProgress, shouldRefresh } from './pullToRefresh';

	interface Props {
		onRefresh: () => Promise<unknown> | unknown;
		disabled?: boolean;
		children?: import('svelte').Snippet;
	}

	let { onRefresh, disabled = false, children }: Props = $props();

	let startY: number | null = null;
	let distance = $state(0);
	let refreshing = $state(false);

	function onTouchStart(event: TouchEvent) {
		if (disabled || refreshing || window.scrollY > 0 || event.touches.length !== 1) return;
		startY = event.touches[0].clientY;
	}

	function onTouchMove(event: TouchEvent) {
		if (startY === null) return;
		distance = pullDistance(event.touches[0].clientY - startY);
	}

	async function onTouchEnd() {
		if (startY === null) return;
		startY = null;
		if (!shouldRefresh(distance)) {
			distance = 0;
			return;
		}
		refreshing = true;
		try {
			await onRefresh();
		} finally {
			refreshing = false;
			distance = 0;
		}
	}
</script>

<div
	role="presentation"
	ontouchstart={onTouchStart}
	ontouchmove={onTouchMove}
	ontouchend={onTouchEnd}
	ontouchcancel={() => {
		startY = null;
		distance = 0;
	}}
>
	{#if distance > 0 || refreshing}
		<div
			class="flex justify-center py-2 transition-transform duration-150 {refreshing
				? 'translate-y-4'
				: indicatorOffsetClass(distance)}"
			role="status"
			aria-live="polite"
		>
			<span
				class="flex items-center gap-2 rounded-full bg-surface-container-high px-3 py-1.5 text-xs font-label font-bold text-on-surface-variant shadow-sm {pullProgress(
					distance
				) >= 1 || refreshing
					? 'opacity-100'
					: 'opacity-60'}"
			>
				<Spinner className="w-4 h-4" />
				{refreshing
					? m('common.refreshing')
					: shouldRefresh(distance)
						? m('common.releaseToRefresh')
						: m('common.pullToRefresh')}
			</span>
		</div>
	{/if}
	{@render children?.()}
</div>
