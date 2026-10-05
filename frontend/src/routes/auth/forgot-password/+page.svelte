<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { authApi } from '$lib/api/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';

	let email = $state('');
	let loading = $state(false);
	let sent = $state(false);
	let error = $state('');

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		loading = true;
		try {
			await authApi.forgotPassword(email);
			sent = true;
		} catch (err) {
			error = errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR');
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>{m('account.forgot.title')} — {m('common.appName')}</title></svelte:head>

<a href="/auth/login" class="flex items-center gap-1 text-on-surface-variant mb-6">
	<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	<span class="text-sm">{m('common.back')}</span>
</a>

{#if sent}
	<div class="text-center space-y-4" role="status">
		<p class="text-on-surface-variant text-sm">{m('account.forgot.sent', { email })}</p>
		<Button variant="secondary" fullWidth onclick={() => (sent = false)}>{m('account.backToLogin')}</Button>
	</div>
{:else}
	<h2 class="text-2xl font-extrabold font-headline mb-6">{m('account.forgot.title')}</h2>
	<form onsubmit={handleSubmit} class="space-y-4">
		{#if error}
			<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3" role="alert">{error}</p>
		{/if}
		<label for="forgot-email" class="sr-only">{m('account.field.email')}</label>
		<input
			id="forgot-email"
			type="email"
			placeholder={m('account.field.email')}
			bind:value={email}
			required
			autocomplete="email"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		<Button type="submit" {loading} fullWidth>{m('account.forgot.submit')}</Button>
	</form>
{/if}
