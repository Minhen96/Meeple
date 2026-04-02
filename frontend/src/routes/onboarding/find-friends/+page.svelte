<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { goto } from '$app/navigation';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';

	let finishing = $state(false);

	async function finish() {
		finishing = true;
		try {
			const updated = await usersApi.updateMe({ onboardingCompleted: true });
			setUser(updated);
			goto('/');
		} catch {
			// Even on failure, let the user proceed
			goto('/');
		}
	}
</script>

<svelte:head><title>Find Friends — Meeple</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">Find your friends</h2>

<input
	type="search"
	placeholder="Search by username"
	class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm mb-4"
/>

<p class="text-sm text-on-surface-variant text-center py-8">Friend discovery coming soon.</p>

<div class="mt-auto pt-8 space-y-3">
	<Button fullWidth loading={finishing} onclick={finish}>Start Exploring</Button>
</div>
