<script lang="ts" module>
	export type PageWidth = 'narrow' | 'wide' | 'full';

	/**
	 * Max width per variant from md up. Below md every variant is the mobile column the app shell
	 * already provides (max-w-lg), so wrapping a page never changes the phone layout.
	 */
	export const PAGE_WIDTHS: Record<PageWidth, string> = {
		narrow: 'md:max-w-xl lg:max-w-2xl',
		wide: 'lg:max-w-6xl',
		full: 'max-w-none'
	};
</script>

<script lang="ts">
	// Content width for a page inside the (app) shell (SCREENS_AND_STATES section 16).
	//   narrow — feed, post detail, forms (same as the shell default: max-w-xl md / max-w-2xl lg)
	//   wide   — grids and dashboards: library, events, profile (max-w-6xl)
	//   full   — edge to edge within the content area (maps, calendars)
	// The shell's <main> drops its own default max width when it contains a PageContainer
	// (matched with :has([data-page-container])), so the variant here wins.
	import type { Snippet } from 'svelte';

	interface Props {
		width?: PageWidth;
		/** Extra classes for the wrapper (spacing, grid…). */
		class?: string;
		children?: Snippet;
	}

	let { width = 'narrow', class: className = '', children }: Props = $props();
</script>

<div data-page-container={width} class="mx-auto w-full {PAGE_WIDTHS[width]} {className}">
	{@render children?.()}
</div>
