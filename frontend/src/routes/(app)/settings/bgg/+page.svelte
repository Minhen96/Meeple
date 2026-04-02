<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { gamesApi } from '$lib/api/games';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';

	let bggUsername = $state('');
	let loading = $state(false);
	let error = $state('');

	async function handleImport(e: Event) {
		e.preventDefault();
		if (!bggUsername.trim()) return;
		error = '';
		loading = true;
		try {
			// Search BGG for the user's top-rated games by username query
			// Full BGG user collection import is a Phase 2 feature
			const results = await gamesApi.search(bggUsername.trim());
			if (results.length === 0) {
				error = 'No games found. Check the BGG username and try again.';
			} else {
				toast.success(`Found ${results.length} games — browse and add them from your library.`);
				goto('/library');
			}
		} catch {
			error = 'Could not reach BoardGameGeek. Try again later.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>BGG Import — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<a href="/settings" class="text-on-surface-variant">
		<span class="material-symbols-outlined">arrow_back</span>
	</a>
	<h2 class="text-xl font-extrabold font-headline">BGG Import</h2>
</div>

<p class="text-sm text-on-surface-variant mb-6">
	Search BoardGameGeek by username to find games you play. Full collection sync is coming in a future update.
</p>

<form onsubmit={handleImport} class="space-y-4">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<input
		type="text"
		placeholder="BGG username"
		bind:value={bggUsername}
		required
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>
	<Button type="submit" fullWidth {loading}>Search</Button>
</form>
