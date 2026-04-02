<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let displayName = $state(data.user?.displayName ?? '');
	let bio = $state(data.user?.bio ?? '');
	let location = $state(data.user?.location ?? '');
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
			goto('/settings');
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

<svelte:head><title>Edit Profile — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<a href="/settings" class="text-on-surface-variant">
		<span class="material-symbols-outlined">arrow_back</span>
	</a>
	<h2 class="text-xl font-extrabold font-headline">Edit Profile</h2>
</div>

<form onsubmit={handleSubmit} class="space-y-4">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Display Name
		</label>
		<input
			type="text"
			bind:value={displayName}
			placeholder="Your name"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Bio
		</label>
		<textarea
			bind:value={bio}
			rows="3"
			placeholder="Tell people about yourself..."
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
		></textarea>
	</div>

	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Location
		</label>
		<input
			type="text"
			bind:value={location}
			placeholder="City, Country"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<Button type="submit" {loading} fullWidth>Save Changes</Button>
</form>
