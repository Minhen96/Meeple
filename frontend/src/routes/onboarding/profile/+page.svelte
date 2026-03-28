<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { goto } from '$app/navigation';

	let displayName = $state('');
	let location = $state('');
	let loading = $state(false);
</script>

<svelte:head><title>Set Up Profile — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">Set up your profile</h2>

<form class="space-y-4" onsubmit={(e) => { e.preventDefault(); goto('/onboarding/bgg-import'); }}>
	<!-- Avatar placeholder -->
	<div class="flex justify-center mb-4">
		<div class="w-24 h-24 rounded-full bg-primary-fixed flex items-center justify-center cursor-pointer hover:opacity-80 transition-opacity">
			<span class="material-symbols-outlined text-primary text-3xl">add_a_photo</span>
		</div>
	</div>

	<input
		type="text"
		placeholder="Display name"
		bind:value={displayName}
		required
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<input
		type="text"
		placeholder="City, Country (optional)"
		bind:value={location}
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<Button type="submit" {loading} fullWidth>Continue</Button>
	<a href="/onboarding/bgg-import" class="block text-center text-sm text-on-surface-variant">Skip</a>
</form>
