<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { goto } from '$app/navigation';
</script>

<svelte:head><title>Add a Game — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-2">What do you love to play?</h2>
<p class="text-sm text-on-surface-variant mb-6">Search for a game to add to your collection.</p>

<input
	type="search"
	placeholder="Search games..."
	class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm mb-4"
/>

<div class="mt-auto pt-8 space-y-3">
	<Button fullWidth onclick={() => goto('/')}>Done</Button>
	<a href="/" class="block text-center text-sm text-on-surface-variant">Skip</a>
</div>
