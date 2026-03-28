<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { api } from '$lib/api/client';

	let email = $state('');
	let loading = $state(false);
	let sent = $state(false);

	async function handleSubmit(e: Event) {
		e.preventDefault();
		loading = true;
		try {
			await api.post('/api/v1/auth/forgot-password', { email });
			sent = true;
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Change Password — Meeple & Hearth</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<a href="/settings" class="text-on-surface-variant">
		<span class="material-symbols-outlined">arrow_back</span>
	</a>
	<h2 class="text-xl font-extrabold font-headline">Change Password</h2>
</div>

{#if sent}
	<div class="text-center space-y-4 py-8">
		<span class="material-symbols-outlined text-6xl text-tertiary">mark_email_unread</span>
		<p class="font-semibold text-on-surface">Reset link sent!</p>
		<p class="text-sm text-on-surface-variant">Check your email for a link to set a new password.</p>
	</div>
{:else}
	<p class="text-sm text-on-surface-variant mb-6">
		Enter your email address and we'll send you a link to set a new password.
	</p>
	<form onsubmit={handleSubmit} class="space-y-4">
		<input
			type="email"
			placeholder="Your email address"
			bind:value={email}
			required
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		<Button type="submit" fullWidth {loading}>Send Reset Link</Button>
	</form>
{/if}
