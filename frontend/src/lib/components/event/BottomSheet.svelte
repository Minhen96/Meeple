<!-- Modal bottom sheet (glass surface, DESIGN section 7). Closes on backdrop tap and Escape.
     From md up (SCREENS_AND_STATES section 16) it renders as a centred dialog without the handle. -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { m } from '$lib/i18n';
	import { MD_QUERY, matchesMedia, motionDuration } from '$lib/utils/media';

	interface Props {
		title: string;
		onClose: () => void;
		children: Snippet;
	}

	let { title, onClose, children }: Props = $props();
	const asDialog = matchesMedia(MD_QUERY);

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}
</script>

<svelte:window onkeydown={onKeydown} />

<div class="fixed inset-0 z-[90] flex items-end justify-center md:items-center md:p-6" role="presentation">
	<button
		type="button"
		class="absolute inset-0 bg-black/40 backdrop-blur-sm cursor-default"
		aria-label={m('event.calendar.close')}
		onclick={onClose}
		transition:fade={{ duration: motionDuration(150) }}
	></button>
	<div
		role="dialog"
		aria-modal="true"
		aria-label={title}
		class="relative w-full max-w-2xl max-h-[75vh] md:max-h-[85vh] overflow-y-auto bg-surface/90 backdrop-blur-xl border border-white/10 rounded-t-lg md:rounded-lg shadow-2xl px-4 md:px-6 pt-3 md:pt-6 pb-28 md:pb-6"
		transition:fly={{ y: asDialog ? 24 : 300, duration: motionDuration(250) }}
	>
		<div class="mx-auto mb-3 h-1.5 w-10 rounded-full bg-on-surface/20 md:hidden" aria-hidden="true"></div>
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
