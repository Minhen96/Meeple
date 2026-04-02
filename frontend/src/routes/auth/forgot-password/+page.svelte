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

<svelte:head><title>Reset Password — Meeple</title></svelte:head>

<a href="/auth/login" class="flex items-center gap-1 text-on-surface-variant mb-6">
	<span class="material-symbols-outlined text-[20px]">arrow_back</span>
	<span class="text-sm">Back</span>
</a>

{#if sent}
	<div class="text-center space-y-4">
		<p class="text-on-surface-variant text-sm">
			If <strong>{email}</strong> is registered, you'll receive a reset link shortly.
		</p>
		<Button variant="secondary" fullWidth onclick={() => (sent = false)}>Back to Login</Button>
	</div>
{:else}
	<h2 class="text-2xl font-extrabold font-headline mb-6">Reset your password</h2>
	<form onsubmit={handleSubmit} class="space-y-4">
		<input
			type="email"
			placeholder="Email address"
			bind:value={email}
			required
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		<Button type="submit" {loading} fullWidth>Send Reset Link</Button>
	</form>
{/if}
