<script lang="ts">
	import Button from "$lib/components/ui/Button.svelte";
	import GoogleButton from "$lib/components/ui/GoogleButton.svelte";
	import { api, ApiRequestError } from "$lib/api/client";
	import { goto } from "$app/navigation";

	let email = $state("");
	let username = $state("");
	let password = $state("");
	let confirmPassword = $state("");
	let loading = $state(false);
	let error = $state("");
	let touched = $state({
		username: false,
		password: false,
		confirmPassword: false,
	});

	// Username availability (debounced)
	let usernameStatus = $state<
		"idle" | "checking" | "available" | "taken" | "error"
	>("idle");
	let usernameTimer: ReturnType<typeof setTimeout>;

	function onUsernameInput() {
		usernameStatus = "idle";
		clearTimeout(usernameTimer);
		if (username.length < 3) return;
		usernameStatus = "checking";
		usernameTimer = setTimeout(async () => {
			try {
				const res = await api.get<{ data: { available: boolean } }>(
					`/api/v1/auth/check-username?username=${encodeURIComponent(username)}`,
				);
				usernameStatus = res.data.available ? "available" : "taken";
			} catch {
				usernameStatus = "error";
			}
		}, 500);
	}

	// Password strength
	const passwordStrength = $derived((): "weak" | "good" | "strong" => {
		if (password.length < 8) return "weak";
		if (password.length >= 12 && /[^a-zA-Z0-9]/.test(password))
			return "strong";
		if (
			password.length >= 8 &&
			/[a-zA-Z]/.test(password) &&
			/[0-9]/.test(password)
		)
			return "good";
		return "weak";
	});

	const strengthColors = {
		weak: "bg-error",
		good: "bg-secondary-container",
		strong: "bg-tertiary",
	};
	const strengthWidths = { weak: "w-1/3", good: "w-2/3", strong: "w-full" };

	// Validation helpers
	const isUsernameValid = $derived(
		username.length >= 3 &&
			username.length <= 20 &&
			/^[a-z][a-z0-9_]*$/.test(username),
	);
	const isPasswordValid = $derived(
		password.length >= 8 &&
			password.length <= 128 &&
			/[A-Z]/.test(password) &&
			/[a-z]/.test(password) &&
			/[0-9]/.test(password) &&
			/[^A-Za-z0-9]/.test(password),
	);
	const doPasswordsMatch = $derived(password === confirmPassword);
	const canSubmit = $derived(
		email.includes("@") &&
			isUsernameValid &&
			isPasswordValid &&
			doPasswordsMatch &&
			usernameStatus !== "taken" &&
			!loading,
	);

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!canSubmit) return;
		error = "";
		loading = true;

		try {
			await api.post("/api/v1/auth/register", {
				email,
				username,
				password,
			});
			goto("/auth/verify-email");
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = "Something went wrong. Please try again.";
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Create Account — Meeple & Hearth</title>
</svelte:head>

<div class="text-center mb-8">
	<h1
		class="text-2xl font-extrabold tracking-tight font-headline text-on-surface"
	>
		Create your account
	</h1>
</div>

<form onsubmit={handleSubmit} class="space-y-4">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">
			{error}
		</p>
	{/if}

	<input
		type="email"
		placeholder="Email"
		bind:value={email}
		required
		autocomplete="email"
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<div>
		<div class="relative">
			<input
				type="text"
				placeholder="Username"
				bind:value={username}
				oninput={() => {
					touched.username = true;
					onUsernameInput();
				}}
				required
				autocomplete="username"
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 pr-10 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
			{#if usernameStatus === "available"}
				<span
					class="absolute right-3 top-1/2 -translate-y-1/2 text-tertiary material-symbols-outlined text-[20px]"
					>check_circle</span
				>
			{:else if usernameStatus === "taken" || (touched.username && !isUsernameValid)}
				<span
					class="absolute right-3 top-1/2 -translate-y-1/2 text-error material-symbols-outlined text-[20px]"
					>cancel</span
				>
			{:else if usernameStatus === "checking"}
				<span
					class="absolute right-3 top-1/2 -translate-y-1/2 text-on-surface-variant animate-spin material-symbols-outlined text-[20px]"
					>progress_activity</span
				>
			{/if}
		</div>
		<p
			class="text-[11px] mt-1 px-1 transition-colors {touched.username &&
			!isUsernameValid
				? 'text-error'
				: 'text-on-surface-variant'}"
		>
			3-20 characters
		</p>
		{#if usernameStatus === "taken"}
			<p class="text-xs text-error mt-1 px-1">Username already taken</p>
		{:else if usernameStatus === "available"}
			<p class="text-xs text-tertiary mt-1 px-1">Username available</p>
		{:else if usernameStatus === "error"}
			<p class="text-xs text-error mt-1 px-1">
				Failed to check username. Is the backend running?
			</p>
		{/if}
	</div>

	<div>
		<input
			type="password"
			placeholder="Password"
			bind:value={password}
			oninput={() => (touched.password = true)}
			required
			autocomplete="new-password"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		<p
			class="text-[11px] mt-1 px-1 transition-colors {touched.password &&
			!isPasswordValid
				? 'text-error'
				: 'text-on-surface-variant'}"
		>
			8-128 chars, with uppercase, lowercase, number, and special char
		</p>
		{#if password.length > 0}
			<div
				class="mt-2 h-1 bg-surface-container-highest rounded-full overflow-hidden"
			>
				<div
					class="h-full rounded-full transition-all {strengthColors[
						passwordStrength()
					]} {strengthWidths[passwordStrength()]}"
				></div>
			</div>
			<p class="text-xs text-on-surface-variant mt-1 px-1 capitalize">
				{passwordStrength()}
			</p>
		{/if}
	</div>

	<div>
		<input
			type="password"
			placeholder="Confirm Password"
			bind:value={confirmPassword}
			oninput={() => (touched.confirmPassword = true)}
			required
			autocomplete="new-password"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		{#if touched.confirmPassword && !doPasswordsMatch}
			<p class="text-xs text-error mt-1 px-1">Passwords do not match</p>
		{/if}
	</div>

	<Button type="submit" {loading} fullWidth disabled={!canSubmit}>
		Create Account
	</Button>

	<div class="relative flex items-center gap-3 py-2">
		<div class="flex-1 h-px bg-outline-variant/30"></div>
		<span class="text-xs text-on-surface-variant font-label">or</span>
		<div class="flex-1 h-px bg-outline-variant/30"></div>
	</div>

	<GoogleButton redirectTo="/" onError={(msg) => (error = msg)} />

	<p class="text-center text-sm text-on-surface-variant">
		Already have an account?
		<a href="/auth/login" class="text-primary font-semibold">Log in</a>
	</p>
</form>
