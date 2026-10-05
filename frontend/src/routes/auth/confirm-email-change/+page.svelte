<script lang="ts">
	// Landing page of the link emailed to a new address (POST /auth/confirm-email-change).
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { authApi } from '$lib/api/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';

	const token = $derived(page.url.searchParams.get('token'));

	let status = $state<'working' | 'done' | 'failed'>('working');
	let error = $state('');

	onMount(async () => {
		if (!token) {
			status = 'failed';
			error = m('account.confirmEmail.invalid');
			return;
		}
		try {
			await authApi.confirmEmailChange(token);
			status = 'done';
		} catch (err) {
			status = 'failed';
			const code = err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR';
			error =
				code === 'TOKEN_EXPIRED' || code === 'INVALID_TOKEN' || code === 'TOKEN_USED'
					? m('account.confirmEmail.invalid')
					: errorMessage(code);
		}
	});
</script>

<svelte:head><title>{m('account.confirmEmail.title')} — {m('common.appName')}</title></svelte:head>

<div class="text-center space-y-4" role="status" aria-live="polite">
	{#if status === 'working'}
		<span class="material-symbols-outlined text-6xl text-tertiary animate-spin">progress_activity</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.confirmEmail.working')}</h2>
	{:else if status === 'done'}
		<span class="material-symbols-outlined text-6xl text-tertiary">check_circle</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.confirmEmail.doneTitle')}</h2>
		<p class="text-sm text-on-surface-variant">{m('account.confirmEmail.doneBody')}</p>
		<a href="/" class="block text-sm text-primary font-semibold">{m('account.confirmEmail.continue')}</a>
	{:else}
		<span class="material-symbols-outlined text-6xl text-error">error</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.confirmEmail.failedTitle')}</h2>
		<p class="text-sm text-on-surface-variant">{error}</p>
		<a href="/settings/change-email" class="block text-sm text-primary font-semibold">{m('account.confirmEmail.retry')}</a>
	{/if}
</div>
