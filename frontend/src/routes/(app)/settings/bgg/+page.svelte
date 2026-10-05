<script lang="ts">
	import BggImportPanel from '$lib/components/game/BggImportPanel.svelte';
	import { m } from '$lib/i18n';
</script>

<svelte:head><title>{m('library.bgg.settingsTitle')} — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<button onclick={() => history.back()} class="text-on-surface-variant" aria-label={m('library.bgg.back')}>
		<span class="material-symbols-outlined">arrow_back</span>
	</button>
	<h2 class="text-xl font-extrabold font-headline">{m('library.bgg.settingsTitle')}</h2>
</div>

<p class="text-sm text-on-surface-variant mb-6">{m('library.bgg.intro')}</p>

<BggImportPanel context="settings">
	{#snippet done()}
		<a
			href="/library"
			class="flex items-center justify-center w-full py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-headline font-bold"
		>
			{m('library.bgg.viewLibrary')}
		</a>
	{/snippet}
</BggImportPanel>
