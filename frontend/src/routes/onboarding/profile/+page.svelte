<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { goto } from '$app/navigation';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';
	import { ApiRequestError } from '$lib/api/client';

	let displayName = $state('');
	let bio = $state('');
	let location = $state('');
	let loading = $state(false);
	let error = $state('');

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		loading = true;
		try {
			const updated = await usersApi.updateMe({
				displayName: displayName || undefined,
				bio: bio || undefined,
				location: location || undefined
			});
			setUser(updated);
			goto('/onboarding/bgg-import');
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = 'Something went wrong.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Set Up Profile — Meeple</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">Set up your profile</h2>

<form class="space-y-4" onsubmit={handleSubmit}>
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<input
		type="text"
		placeholder="Display name"
		bind:value={displayName}
		required
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<textarea
		placeholder="Bio (optional)"
		bind:value={bio}
		rows="2"
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
	></textarea>

	<input
		type="text"
		placeholder="City, Country (optional)"
		bind:value={location}
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<Button type="submit" {loading} fullWidth>Continue</Button>
	<a href="/onboarding/bgg-import" class="block text-center text-sm text-on-surface-variant">Skip</a>
</form>
