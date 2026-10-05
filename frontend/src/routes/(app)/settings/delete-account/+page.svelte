<script lang="ts">
	// Delete account (SCREENS_AND_STATES section 11.5; decision C11): password accounts confirm
	// with the password, Google-only accounts type DELETE. A bottom-sheet confirmation follows.
	// The account is scheduled for deletion and can be reactivated for 30 days.
	import { goto } from '$app/navigation';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import { ApiRequestError } from '$lib/api/client';
	import { usersApi } from '$lib/api/users';
	import { errorMessage, m } from '$lib/i18n';
	import { clearClientSession } from '$lib/session';
	import type { DeleteAccountRequest } from '$lib/types';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const hasPassword = $derived(data.user?.hasPassword !== false);
	let password = $state('');
	let typed = $state('');
	let confirming = $state(false);
	let loading = $state(false);
	let error = $state('');

	const ready = $derived(hasPassword ? password.length > 0 : typed === 'DELETE');

	function askConfirmation(event: Event) {
		event.preventDefault();
		if (ready) confirming = true;
	}

	async function deleteAccount() {
		loading = true;
		error = '';
		const body: DeleteAccountRequest = hasPassword ? { password } : { confirm: 'DELETE' };
		try {
			await usersApi.deleteMe(body);
			clearClientSession();
			void goto('/auth/login?deleted=1');
		} catch (err) {
			confirming = false;
			error = errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR');
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>{m('account.delete.title')} — {m('common.appName')}</title></svelte:head>

<PageHeader title={m('account.delete.title')} />

<div class="bg-error/10 rounded-xl p-4 mb-6 space-y-2">
	<p class="font-semibold text-error text-sm">{m('account.delete.warningTitle')}</p>
	<ul class="text-sm text-on-surface-variant list-disc pl-5 space-y-1">
		<li>{m('account.delete.consequenceGrace')}</li>
		<li>{m('account.delete.consequenceImmediate')}</li>
		<li>{m('account.delete.consequencePermanent')}</li>
	</ul>
</div>

{#if error}
	<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3 mb-4" role="alert">{error}</p>
{/if}

<form class="space-y-4" onsubmit={askConfirmation}>
	{#if hasPassword}
		<div>
			<label for="delete-password" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
				{m('account.delete.passwordLabel')}
			</label>
			<input
				id="delete-password"
				type="password"
				bind:value={password}
				autocomplete="current-password"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-error/20 focus:outline-none font-body text-sm"
			/>
		</div>
	{:else}
		<div>
			<label for="delete-typed" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
				{m('account.delete.typeLabel')}
			</label>
			<input
				id="delete-typed"
				type="text"
				bind:value={typed}
				placeholder="DELETE"
				autocapitalize="characters"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-error/20 focus:outline-none font-body text-sm"
			/>
		</div>
	{/if}

	<Button type="submit" variant="danger" fullWidth disabled={!ready || loading}>
		{m('account.delete.submit')}
	</Button>
</form>

{#if confirming}
	<ConfirmDialog
		danger
		icon="person_remove"
		title={m('account.delete.confirmTitle')}
		message={m('account.delete.confirmBody')}
		confirmLabel={m('account.delete.confirmAction')}
		{loading}
		onConfirm={deleteAccount}
		onCancel={() => (confirming = false)}
	/>
{/if}
