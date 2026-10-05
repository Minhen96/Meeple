<script lang="ts">
	// Change email (FEATURES_COMPLETE section 1.7): current password + new address; a link is
	// sent to the new address and the change applies when it is opened.
	import Button from '$lib/components/ui/Button.svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import { ApiRequestError } from '$lib/api/client';
	import { usersApi } from '$lib/api/users';
	import { errorMessage, m } from '$lib/i18n';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const hasPassword = $derived(data.user?.hasPassword !== false);
	let newEmail = $state('');
	let currentPassword = $state('');
	let loading = $state(false);
	let sentTo = $state<string | null>(null);
	let error = $state('');

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		loading = true;
		try {
			await usersApi.changeEmail(currentPassword, newEmail.trim());
			sentTo = newEmail.trim();
			currentPassword = '';
		} catch (err) {
			error = errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR');
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>{m('account.email.title')} — {m('common.appName')}</title></svelte:head>

<PageHeader title={m('account.email.title')} />

{#if data.user?.email}
	<p class="text-sm text-on-surface-variant mb-6">
		{m('account.email.current', { email: data.user.email })}
	</p>
{/if}

{#if !hasPassword}
	<div class="bg-surface-container-low rounded-xl p-4 text-sm text-on-surface-variant">
		{m('account.email.googleOnly')}
	</div>
{:else if sentTo}
	<div class="text-center space-y-4 py-8" role="status">
		<span class="material-symbols-outlined text-6xl text-tertiary">mark_email_unread</span>
		<p class="font-semibold text-on-surface">{m('account.email.sentTitle')}</p>
		<p class="text-sm text-on-surface-variant">{m('account.email.sentBody', { email: sentTo })}</p>
	</div>
{:else}
	<form onsubmit={handleSubmit} class="space-y-4">
		{#if error}
			<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3" role="alert">{error}</p>
		{/if}
		<div>
			<label for="new-email" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
				{m('account.email.newLabel')}
			</label>
			<input
				id="new-email"
				type="email"
				bind:value={newEmail}
				required
				maxlength="255"
				autocomplete="email"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
		</div>
		<div>
			<label for="current-password" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
				{m('account.email.passwordLabel')}
			</label>
			<input
				id="current-password"
				type="password"
				bind:value={currentPassword}
				required
				autocomplete="current-password"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
		</div>
		<Button type="submit" fullWidth {loading} disabled={!newEmail || !currentPassword}>
			{m('account.email.submit')}
		</Button>
	</form>
{/if}
