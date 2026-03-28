<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { goto } from '$app/navigation';
</script>

<svelte:head><title>Import Collection — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-2">Import your collection</h2>
<p class="text-sm text-on-surface-variant mb-6">Connect your BoardGameGeek account to import your games.</p>

<div class="space-y-4">
	<input
		type="text"
		placeholder="BGG username"
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>
	<p class="text-xs text-on-surface-variant px-1">We only read your public collection.</p>
	<Button fullWidth>Import Collection</Button>
	<a href="/onboarding/find-friends" class="block text-center text-sm text-on-surface-variant">Skip</a>
</div>
