<!-- Modal bottom sheet (glass surface, DESIGN section 7). Closes on backdrop tap and Escape. -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { m } from '$lib/i18n';

	interface Props {
		title: string;
		onClose: () => void;
		children: Snippet;
	}

	let { title, onClose, children }: Props = $props();

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}
</script>

<svelte:window onkeydown={onKeydown} />

<div class="fixed inset-0 z-[90] flex items-end justify-center" role="presentation">
	<button
		type="button"
		class="absolute inset-0 bg-black/40 backdrop-blur-sm cursor-default"
		aria-label={m('event.calendar.close')}
		onclick={onClose}
		transition:fade={{ duration: 150 }}
	></button>
	<div
		role="dialog"
		aria-modal="true"
		aria-label={title}
		class="relative w-full max-w-2xl max-h-[75vh] overflow-y-auto bg-surface/90 backdrop-blur-xl border border-white/10 rounded-t-lg shadow-2xl px-4 pt-3 pb-28"
		transition:fly={{ y: 300, duration: 250 }}
	>
		<div class="mx-auto mb-3 h-1.5 w-10 rounded-full bg-on-surface/20" aria-hidden="true"></div>
		<div class="flex items-center justify-between mb-4">
			<h3 class="text-lg font-headline font-extrabold text-on-surface">{title}</h3>
			<button
				type="button"
				onclick={onClose}
				class="w-9 h-9 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface-variant spring-bounce"
				aria-label={m('event.calendar.close')}
			>
				<span class="material-symbols-outlined text-[20px]" aria-hidden="true">close</span>
			</button>
		</div>
		{@render children()}
	</div>
</div>
