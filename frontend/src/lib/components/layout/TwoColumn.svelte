<script lang="ts">
	// Main column + right rail (SCREENS_AND_STATES section 16). The rail sits beside the content
	// from xl (≥ 1280px) and sticks while the main column scrolls; below xl it is hidden, or stacked
	// under the main content with `stackAside`. Use inside <PageContainer width="wide">.
	import type { Snippet } from 'svelte';

	interface Props {
		/** Main column. */
		children?: Snippet;
		/** Right rail content (suggestions, upcoming events, filters…). */
		aside?: Snippet;
		/** Accessible name of the rail landmark. */
		asideLabel?: string;
		/** Below xl, show the rail under the main column instead of hiding it. */
		stackAside?: boolean;
		class?: string;
	}

	let { children, aside, asideLabel, stackAside = false, class: className = '' }: Props = $props();
</script>

<div
	class="xl:grid xl:grid-cols-[minmax(0,1fr)_20rem] xl:gap-8 xl:items-start {className}"
	data-two-column
>
	<div class="min-w-0">
		{@render children?.()}
	</div>
	{#if aside}
		<aside
			aria-label={asideLabel}
			class="{stackAside ? 'mt-8 xl:mt-0' : 'hidden xl:block'} min-w-0 xl:sticky xl:top-8"
			data-stacked={stackAside ? 'true' : 'false'}
		>
			{@render aside()}
		</aside>
	{/if}
</div>
