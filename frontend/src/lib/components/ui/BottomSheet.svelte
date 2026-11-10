<script lang="ts">
	// Bottom sheet (SCREENS_AND_STATES section 14.2): handle, content, backdrop. Escape and a
	// backdrop tap close it; focus moves into the sheet on open and back to the trigger on close.
	// From md up (section 16) the same component renders as a centred modal dialog without the
	// handle; transitions collapse under prefers-reduced-motion.
	import { onMount, tick } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { m } from '$lib/i18n';
	import { MD_QUERY, matchesMedia, motionDuration } from '$lib/utils/media';

	interface Props {
		title?: string;
		/** Accessible label when there is no visible title. */
		label?: string;
		onClose: () => void;
		children?: import('svelte').Snippet;
	}

	let { title, label, onClose, children }: Props = $props();
	let sheet: HTMLDivElement;
	// Read once on open: a sheet slides up from the bottom edge, a dialog rises a little.
	const asDialog = matchesMedia(MD_QUERY);

	onMount(() => {
		const trigger = document.activeElement instanceof HTMLElement ? document.activeElement : null;
		void tick().then(() => {
			const focusable = sheet?.querySelector<HTMLElement>(
				'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
			);
			(focusable ?? sheet)?.focus();
		});
		return () => trigger?.focus();
	});

	function onKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			event.stopPropagation();
			onClose();
		}
	}
</script>

<svelte:window onkeydown={onKeydown} />

<div
	class="fixed inset-0 z-[100] flex items-end justify-center md:items-center md:p-6"
	transition:fade={{ duration: motionDuration(150) }}
>
	<button
		type="button"
		class="absolute inset-0 bg-black/50 backdrop-blur-sm"
		aria-label={m('common.close')}
		onclick={onClose}
	></button>
	<div
		bind:this={sheet}
		role="dialog"
		aria-modal="true"
		aria-label={title ?? label}
		tabindex="-1"
		class="relative w-full max-w-lg bg-surface rounded-t-[2rem] md:rounded-[2rem] shadow-2xl px-6 pt-3 md:pt-6 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] md:pb-6 max-h-[90vh] md:max-h-[85vh] overflow-y-auto focus:outline-none"
		transition:fly={{ y: asDialog ? 24 : 400, duration: motionDuration(250) }}
	>
		<div class="mx-auto mb-4 h-1.5 w-10 rounded-full bg-surface-container-highest md:hidden"></div>
		{#if title}
			<h2 class="text-lg font-headline font-extrabold text-on-surface mb-4">{title}</h2>
		{/if}
		{@render children?.()}
	</div>
</div>
