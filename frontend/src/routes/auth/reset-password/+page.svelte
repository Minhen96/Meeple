<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { authApi } from '$lib/api/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';

	const token = $derived(page.url.searchParams.get('token') ?? '');

	let password = $state('');
	let confirm = $state('');
	let loading = $state(false);
	let done = $state(false);
	let error = $state('');

	const mismatch = $derived(confirm.length > 0 && password !== confirm);
	const tooShort = $derived(password.length > 0 && password.length < 8);

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (mismatch || password.length < 8) return;
		error = '';
		loading = true;
		try {
			await authApi.resetPassword(token, password);
			done = true;
			setTimeout(() => goto('/auth/login'), 2000);
		} catch (err) {
			error =
				err instanceof ApiRequestError && (err.code === 'TOKEN_EXPIRED' || err.code === 'INVALID_TOKEN' || err.code === 'TOKEN_USED')
					? m('account.reset.linkExpired')
					: errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR');
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>{m('account.reset.title')} — {m('common.appName')}</title></svelte:head>

{#if !token}
	<div class="text-center space-y-4">
		<span class="material-symbols-outlined text-6xl text-error">error</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.reset.invalidTitle')}</h2>
		<p class="text-sm text-on-surface-variant">{m('account.reset.invalidBody')}</p>
		<a href="/auth/forgot-password" class="block text-primary font-semibold text-sm">{m('account.reset.requestNew')}</a>
	</div>
{:else if done}
	<div class="text-center space-y-4" role="status">
		<span class="material-symbols-outlined text-6xl text-tertiary">check_circle</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.reset.doneTitle')}</h2>
		<p class="text-sm text-on-surface-variant">{m('account.redirectingToLogin')}</p>
	</div>
{:else}
	<h2 class="text-2xl font-extrabold font-headline mb-6">{m('account.reset.title')}</h2>

	<form onsubmit={handleSubmit} class="space-y-4">
		{#if error}
			<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3" role="alert">{error}</p>
		{/if}

		<div>
			<label for="new-password" class="sr-only">{m('account.reset.newPassword')}</label>
			<input
				id="new-password"
				type="password"
				placeholder={m('account.reset.newPassword')}
				bind:value={password}
				required
				minlength="8"
				autocomplete="new-password"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
			{#if tooShort}
				<p class="text-xs text-error mt-1 px-1">{m('account.password.minLength')}</p>
			{/if}
		</div>

		<div>
			<label for="confirm-password" class="sr-only">{m('account.reset.confirmPassword')}</label>
			<input
				id="confirm-password"
				type="password"
				placeholder={m('account.reset.confirmPassword')}
				bind:value={confirm}
				required
				autocomplete="new-password"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
			{#if mismatch}
				<p class="text-xs text-error mt-1 px-1">{m('account.password.mismatch')}</p>
			{/if}
		</div>

		<Button type="submit" {loading} fullWidth disabled={mismatch || password.length < 8}>
			{m('account.reset.submit')}
		</Button>

		<a href="/auth/login" class="block text-center text-sm text-on-surface-variant">{m('account.backToLogin')}</a>
	</form>
{/if}
