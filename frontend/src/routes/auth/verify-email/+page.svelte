<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import Button from '$lib/components/ui/Button.svelte';
	import { authApi } from '$lib/api/auth';
	import { m } from '$lib/i18n';

	// Token comes from the email link: /auth/verify-email?token=abc123
	const token = $derived(page.url.searchParams.get('token'));

	let verifying = $state(false);
	let verified = $state(false);
	let failed = $state(false);
	let resendEmail = $state('');
	let resending = $state(false);
	let resent = $state(false);

	onMount(async () => {
		if (!token) return;
		verifying = true;
		try {
			await authApi.verifyEmail(token);
			verified = true;
			// Auto-login cookies are set — continue into the app after a short delay
			setTimeout(() => {
				window.location.href = '/';
			}, 1500);
		} catch {
			failed = true;
		} finally {
			verifying = false;
		}
	});

	async function resend() {
		if (!resendEmail) return;
		resending = true;
		try {
			await authApi.resendVerification(resendEmail);
		} catch {
			// The answer never reveals whether the address exists
		} finally {
			resent = true;
			resending = false;
		}
	}
</script>

<svelte:head><title>{m('account.verify.title')} — {m('common.appName')}</title></svelte:head>

<div class="text-center space-y-4">
	{#if verifying}
		<span class="material-symbols-outlined text-6xl text-tertiary animate-spin">progress_activity</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.verify.verifying')}</h2>
	{:else if verified}
		<span class="material-symbols-outlined text-6xl text-tertiary">check_circle</span>
		<h2 class="text-2xl font-extrabold font-headline">{m('account.verify.doneTitle')}</h2>
		<p class="text-on-surface-variant text-sm">{m('account.verify.doneBody')}</p>
	{:else}
		{#if failed}
			<span class="material-symbols-outlined text-6xl text-error">error</span>
			<h2 class="text-2xl font-extrabold font-headline">{m('account.verify.expiredTitle')}</h2>
			<p class="text-on-surface-variant text-sm">{m('account.verify.expiredBody')}</p>
		{:else}
			<span class="material-symbols-outlined text-6xl text-tertiary">mark_email_unread</span>
			<h2 class="text-2xl font-extrabold font-headline">{m('account.verify.checkInbox')}</h2>
			<p class="text-on-surface-variant text-sm">{m('account.verify.sentBody')}</p>
		{/if}

		{#if resent}
			<p class="text-sm text-tertiary font-semibold" role="status">{m('account.verify.resent')}</p>
		{:else}
			<div class="space-y-2 pt-2">
				<label for="resend-email" class="sr-only">{m('account.field.email')}</label>
				<input
					id="resend-email"
					type="email"
					placeholder={m('account.verify.resendPlaceholder')}
					bind:value={resendEmail}
					autocomplete="email"
					class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
				/>
				<Button variant={failed ? 'primary' : 'secondary'} fullWidth loading={resending} onclick={resend}>
					{m('account.verify.resend')}
				</Button>
			</div>
		{/if}
	{/if}

	<a href="/auth/login" class="block text-sm text-primary font-semibold">{m('account.backToLogin')}</a>
</div>
