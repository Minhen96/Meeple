<script lang="ts">
	// Change password: emails a reset link to the account's address (same flow as "forgot
	// password"; the link sets the new password and signs out every device).
	import Button from '$lib/components/ui/Button.svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import { authApi } from '$lib/api/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	// Pre-filled with the account email; still editable
	let email = $derived(data.user?.email ?? '');
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

<svelte:head><title>{m('account.password.title')} — {m('common.appName')}</title></svelte:head>

<PageHeader title={m('account.password.title')} />

{#if sent}
	<div class="text-center space-y-4 py-8" role="status">
		<span class="material-symbols-outlined text-6xl text-tertiary">mark_email_unread</span>
		<p class="font-semibold text-on-surface">{m('account.password.sentTitle')}</p>
		<p class="text-sm text-on-surface-variant">{m('account.password.sentBody')}</p>
	</div>
{:else}
	<p class="text-sm text-on-surface-variant mb-6">{m('account.password.intro')}</p>
	<form onsubmit={handleSubmit} class="space-y-4">
		{#if error}
			<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3" role="alert">{error}</p>
		{/if}
		<label for="reset-email" class="sr-only">{m('account.field.email')}</label>
		<input
			id="reset-email"
			type="email"
			placeholder={m('account.field.email')}
			bind:value={email}
			required
			autocomplete="email"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		<Button type="submit" fullWidth {loading}>{m('account.password.send')}</Button>
	</form>
{/if}
