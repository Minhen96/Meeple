<script lang="ts">
	// Back button + title for immersive sub-pages (settings, …). Back stays in the app; after a
	// deep link it goes to the logical parent.
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { m } from '$lib/i18n';
	import { hasInAppHistory, logicalParent } from './navigation';

	interface Props {
		title: string;
		eyebrow?: string;
	}

	let { title, eyebrow }: Props = $props();

	function back() {
		if (hasInAppHistory()) history.back();
		else void goto(logicalParent(page.url.pathname));
	}
</script>

<div class="flex items-center gap-3 mb-6 mt-3">
	<button
		type="button"
		onclick={back}
		class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
		aria-label={m('common.back')}
	>
		<span class="material-symbols-outlined text-[22px]">arrow_back</span>
	</button>
	<div>
		{#if eyebrow}
			<p class="text-[10px] font-bold uppercase tracking-widest text-primary mb-0.5">{eyebrow}</p>
		{/if}
		<h2 class="text-xl font-extrabold font-headline">{title}</h2>
	</div>
</div>
