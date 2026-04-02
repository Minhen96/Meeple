<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';
	import { goto } from '$app/navigation';

	let confirmed = $state('');
	let loading = $state(false);
	let error = $state('');

	const canDelete = $derived(confirmed === 'DELETE');

	async function handleDelete() {
		if (!canDelete) return;
		loading = true;
		error = '';
		try {
			await usersApi.deleteMe();
			setUser(null);
			goto('/auth/login');
		} catch {
			error = 'Could not delete account. Please try again.';
			loading = false;
		}
	}
</script>

<svelte:head><title>Delete Account — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<a href="/settings" class="text-on-surface-variant">
		<span class="material-symbols-outlined">arrow_back</span>
	</a>
	<h2 class="text-xl font-extrabold font-headline">Delete Account</h2>
</div>

<div class="bg-error/10 rounded-xl p-4 mb-6 space-y-2">
	<p class="font-semibold text-error text-sm">This action is permanent</p>
	<p class="text-sm text-on-surface-variant">
		Your account, collection, posts, and events will be permanently deleted. This cannot be undone.
	</p>
</div>

{#if error}
	<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3 mb-4">{error}</p>
{/if}

<div class="space-y-4">
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Type DELETE to confirm
		</label>
		<input
			type="text"
			bind:value={confirmed}
			placeholder="DELETE"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-error/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<button
		onclick={handleDelete}
		disabled={!canDelete || loading}
		class="w-full py-3 rounded-xl text-sm font-label font-bold bg-error text-on-primary disabled:opacity-40 transition-opacity"
	>
		{loading ? 'Deleting…' : 'Permanently Delete Account'}
	</button>
</div>
