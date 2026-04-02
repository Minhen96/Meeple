<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { api, ApiRequestError } from '$lib/api/client';
	import { onMount } from 'svelte';

	// Token comes from the email link: /auth/verify-email?token=abc123
	const token = $derived($page.url.searchParams.get('token'));

	let verifying = $state(false);
	let verified = $state(false);
	let error = $state('');
	let resendEmail = $state('');
	let resending = $state(false);
	let resent = $state(false);

	onMount(async () => {
		if (token) {
			verifying = true;
			try {
				await api.post('/api/v1/auth/verify-email', { token });
				verified = true;
				// Auto-login cookies are set — redirect after short delay
				setTimeout(() => { window.location.href = '/'; }, 1500);
			} catch (err) {
				if (err instanceof ApiRequestError) {
					error = err.message;
				} else {
					error = 'Verification failed. The link may have expired.';
				}
			} finally {
				verifying = false;
			}
		}
	});

	async function resend() {
		if (!resendEmail) return;
		resending = true;
		try {
			await api.post('/api/v1/auth/resend-verification', { email: resendEmail });
			resent = true;
		} catch {
			// Silently succeed — don't reveal if email exists
			resent = true;
		} finally {
			resending = false;
		}
	}
</script>

<svelte:head><title>Verify Email — Meeple</title></svelte:head>

<div class="text-center space-y-4">
	{#if verifying}
		<span class="material-symbols-outlined text-6xl text-tertiary animate-spin">progress_activity</span>
		<h2 class="text-2xl font-extrabold font-headline">Verifying…</h2>

	{:else if verified}
		<span class="material-symbols-outlined text-6xl text-tertiary">check_circle</span>
		<h2 class="text-2xl font-extrabold font-headline">Email verified!</h2>
		<p class="text-on-surface-variant text-sm">Taking you to the app…</p>

	{:else if error}
		<span class="material-symbols-outlined text-6xl text-error">error</span>
		<h2 class="text-2xl font-extrabold font-headline">Link expired</h2>
		<p class="text-on-surface-variant text-sm">{error}</p>
		<div class="space-y-2 pt-2">
			<input
				type="email"
				placeholder="Enter your email to resend"
				bind:value={resendEmail}
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
			<Button fullWidth loading={resending} onclick={resend}>Resend verification email</Button>
		</div>

	{:else}
		<!-- No token — user just registered -->
		<span class="material-symbols-outlined text-6xl text-tertiary">mark_email_unread</span>
		<h2 class="text-2xl font-extrabold font-headline">Check your inbox</h2>
		<p class="text-on-surface-variant text-sm">We sent a verification link to your email address.</p>

		{#if resent}
			<p class="text-sm text-tertiary font-semibold">✓ Sent! Check your inbox again.</p>
		{:else}
			<div class="space-y-2 pt-2">
				<input
					type="email"
					placeholder="Didn't get it? Enter your email"
					bind:value={resendEmail}
					class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
				/>
				<Button variant="secondary" fullWidth loading={resending} onclick={resend}>Resend email</Button>
			</div>
		{/if}
	{/if}

	<a href="/auth/login" class="block text-sm text-primary font-semibold">Back to login</a>
</div>
