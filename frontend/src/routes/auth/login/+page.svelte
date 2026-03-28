<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { api, ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	let emailOrUsername = $state('');
	let password = $state('');
	let showPassword = $state(false);
	let loading = $state(false);
	let error = $state('');

	const redirectTo = $derived($page.url.searchParams.get('redirect') ?? '/');

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		loading = true;

		try {
			await api.post('/api/v1/auth/login', { emailOrUsername, password });
			goto(redirectTo);
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = 'Something went wrong. Please try again.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Log In — Meeple & Hearth</title>
</svelte:head>

<!-- Brand -->
<div class="text-center mb-8">
	<h1 class="text-3xl font-extrabold tracking-tight font-headline text-primary">Meeple & Hearth</h1>
	<p class="mt-1 text-on-surface-variant text-sm">Welcome back</p>
</div>

<form onsubmit={handleSubmit} class="space-y-4">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<input
		type="text"
		placeholder="Email or username"
		bind:value={emailOrUsername}
		required
		autocomplete="username"
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<div class="relative">
		<input
			type={showPassword ? 'text' : 'password'}
			placeholder="Password"
			bind:value={password}
			required
			autocomplete="current-password"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 pr-12 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		<button
			type="button"
			onclick={() => (showPassword = !showPassword)}
			class="absolute right-3 top-1/2 -translate-y-1/2 text-on-surface-variant"
			aria-label="Toggle password visibility"
		>
			<span class="material-symbols-outlined text-[20px]">
				{showPassword ? 'visibility_off' : 'visibility'}
			</span>
		</button>
	</div>

	<div class="text-right">
		<a href="/auth/forgot-password" class="text-xs text-primary font-semibold">Forgot password?</a>
	</div>

	<Button type="submit" {loading} fullWidth>Log In</Button>

	<div class="relative flex items-center gap-3 py-2">
		<div class="flex-1 h-px bg-outline-variant/30"></div>
		<span class="text-xs text-on-surface-variant font-label">or</span>
		<div class="flex-1 h-px bg-outline-variant/30"></div>
	</div>

	<p class="text-center text-sm text-on-surface-variant">
		Don't have an account?
		<a href="/auth/register" class="text-primary font-semibold">Create account</a>
	</p>
</form>
