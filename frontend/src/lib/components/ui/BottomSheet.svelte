<script lang="ts">
	// Bottom sheet (SCREENS_AND_STATES section 14.2): handle, content, backdrop. Escape and a
	// backdrop tap close it; focus moves into the sheet on open and back to the trigger on close.
	import { onMount, tick } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { m } from '$lib/i18n';

	interface Props {
		title?: string;
		/** Accessible label when there is no visible title. */
		label?: string;
		onClose: () => void;
		children?: import('svelte').Snippet;
	}

	let { title, label, onClose, children }: Props = $props();
	let sheet: HTMLDivElement;

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

<div class="fixed inset-0 z-[100] flex items-end justify-center" transition:fade={{ duration: 150 }}>
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
		class="relative w-full max-w-lg bg-surface rounded-t-[2rem] shadow-2xl px-6 pt-3 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] max-h-[90vh] overflow-y-auto focus:outline-none"
		transition:fly={{ y: 400, duration: 250 }}
	>
		<div class="mx-auto mb-4 h-1.5 w-10 rounded-full bg-surface-container-highest"></div>
		{#if title}
			<h2 class="text-lg font-headline font-extrabold text-on-surface mb-4">{title}</h2>
		{/if}
		{@render children?.()}
	</div>
</div>
