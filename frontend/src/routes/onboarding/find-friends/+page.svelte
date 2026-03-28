<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { goto } from '$app/navigation';
</script>

<svelte:head><title>Find Friends — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">Find your friends</h2>

<input
	type="search"
	placeholder="Search by username"
	class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm mb-4"
/>

<p class="text-sm text-on-surface-variant text-center py-8">No suggestions yet.</p>

<div class="mt-auto pt-8 space-y-3">
	<Button fullWidth onclick={() => goto('/onboarding/add-game')}>Continue</Button>
	<a href="/onboarding/add-game" class="block text-center text-sm text-on-surface-variant">Skip</a>
</div>
