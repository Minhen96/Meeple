<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { api, ApiRequestError } from '$lib/api/client';

	const token = $derived($page.url.searchParams.get('token') ?? '');

	let password = $state('');
	let confirm = $state('');
	let loading = $state(false);
	let done = $state(false);
	let error = $state('');

	const mismatch = $derived(confirm.length > 0 && password !== confirm);

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (mismatch || password.length < 8) return;
		error = '';
		loading = true;
		try {
			await api.post('/api/v1/auth/reset-password', { token, newPassword: password });
			done = true;
			setTimeout(() => goto('/auth/login'), 2000);
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = 'Link may have expired. Request a new one.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Set New Password — Meeple & Hearth</title></svelte:head>

{#if !token}
	<div class="text-center space-y-4">
		<span class="material-symbols-outlined text-6xl text-error">error</span>
		<h2 class="text-2xl font-extrabold font-headline">Invalid link</h2>
		<p class="text-sm text-on-surface-variant">This password reset link is invalid or expired.</p>
		<a href="/auth/forgot-password" class="block text-primary font-semibold text-sm">Request a new link</a>
	</div>

{:else if done}
	<div class="text-center space-y-4">
		<span class="material-symbols-outlined text-6xl text-tertiary">check_circle</span>
		<h2 class="text-2xl font-extrabold font-headline">Password updated!</h2>
		<p class="text-sm text-on-surface-variant">Taking you to login…</p>
	</div>

{:else}
	<h2 class="text-2xl font-extrabold font-headline mb-6">Set new password</h2>

	<form onsubmit={handleSubmit} class="space-y-4">
		{#if error}
			<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
		{/if}

		<div>
			<input
				type="password"
				placeholder="New password"
				bind:value={password}
				required
				minlength="8"
				autocomplete="new-password"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
			{#if password.length > 0 && password.length < 8}
				<p class="text-xs text-error mt-1 px-1">At least 8 characters</p>
			{/if}
		</div>

		<div>
			<input
				type="password"
				placeholder="Confirm new password"
				bind:value={confirm}
				required
				autocomplete="new-password"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
			{#if mismatch}
				<p class="text-xs text-error mt-1 px-1">Passwords do not match</p>
			{/if}
		</div>

		<Button type="submit" {loading} fullWidth disabled={mismatch || password.length < 8}>
			Update Password
		</Button>

		<a href="/auth/login" class="block text-center text-sm text-on-surface-variant">
			Back to login
		</a>
	</form>
{/if}
