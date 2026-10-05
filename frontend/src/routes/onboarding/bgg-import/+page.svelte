<script lang="ts">
	import BggImportPanel from '$lib/components/game/BggImportPanel.svelte';
	import { m } from '$lib/i18n';

	const NEXT_STEP = '/onboarding/find-friends';
</script>

<svelte:head><title>{m('library.bgg.title')} — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-2">
	<span class="material-symbols-outlined text-primary text-[28px]">inventory_2</span>
	<h2 class="text-2xl font-extrabold font-headline">{m('library.bgg.title')}</h2>
</div>
<p class="text-sm text-on-surface-variant mb-6">{m('library.bgg.intro')}</p>

<BggImportPanel context="onboarding">
	{#snippet done()}
		<a
			href={NEXT_STEP}
			class="flex items-center justify-center w-full py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-headline font-bold"
		>
			{m('library.bgg.continue')}
		</a>
	{/snippet}
</BggImportPanel>

<a href={NEXT_STEP} class="block text-center text-sm text-on-surface-variant mt-4">{m('library.bgg.skip')}</a>
