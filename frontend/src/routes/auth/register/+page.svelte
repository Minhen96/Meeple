<script lang="ts">
	import Button from "$lib/components/ui/Button.svelte";
	import GoogleButton from "$lib/components/ui/GoogleButton.svelte";
	import { api, ApiRequestError } from "$lib/api/client";
	import { goto } from "$app/navigation";
	import AppBar from "$lib/components/layout/AppBar.svelte";

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
			/^[a-z0-9][a-z0-9_]*$/.test(username),
	);
	const usernameError = $derived.by((): string => {
		if (!touched.username || username.length === 0) return "";
		if (username.length < 3) return "Too short — minimum 3 characters";
		if (username.length > 20) return "Too long — maximum 20 characters";
		if (!/^[a-z0-9]/.test(username))
			return "Must start with a letter or number";
		if (!/^[a-z0-9][a-z0-9_]*$/.test(username))
			return "Only letters, numbers, and underscores allowed";
		return "";
	});
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
	<title>Create Account — Meeple</title>
</svelte:head>

<!-- Premium Game Board Background -->
<div class="fixed inset-0 -z-10 bg-[#ebe8e2] dark:bg-surface overflow-hidden">
	<!-- Base Gradients -->
	<div
		class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-from),_transparent_70%),_radial-gradient(circle_at_bottom_left,_var(--tw-gradient-to),_transparent_70%)] from-secondary/30 to-tertiary/30 opacity-90"
	></div>

	<!-- Board Grid Pattern -->
	<div
		class="absolute inset-0 opacity-[0.06] dark:opacity-[0.08] [background-image:radial-gradient(circle_at_center,_#000_1px,transparent_1px)] [background-size:32px_32px]"
	></div>
	<div
		class="absolute inset-0 opacity-[0.04] dark:opacity-[0.06] [background-image:linear-gradient(to_right,#000_1px,transparent_1px),linear-gradient(to_bottom,#000_1px,transparent_1px)] [background-size:128px_128px]"
	></div>

	<!-- Floating Immersive Assets -->
	<div class="absolute inset-0 pointer-events-none">
		<!-- Floating Cards Stack -->
		<div
			class="absolute top-[10%] right-[10%] w-32 h-44 bg-white/5 dark:bg-white/10 backdrop-blur-3xl rounded-xl border border-white/10 shadow-2xl transform -rotate-12 animate-float opacity-40 hidden lg:block overflow-hidden"
		>
			<div
				class="absolute top-2 right-2 w-6 h-6 rounded-full bg-secondary/20"
			></div>
		</div>
		<div
			class="absolute top-[12%] right-[12%] w-32 h-44 bg-white/5 dark:bg-white/10 backdrop-blur-3xl rounded-xl border border-white/10 shadow-2xl transform rotate-6 animate-float-slow opacity-30 hidden lg:block overflow-hidden"
		></div>

		<!-- Floating Die (D6) -->
		<div
			class="absolute bottom-[15%] left-[10%] w-20 h-20 bg-secondary/10 backdrop-blur-2xl rounded-2xl border border-secondary/20 shadow-xl transform rotate-12 animate-float hidden md:flex items-center justify-center"
		>
			<div class="grid grid-cols-2 gap-2 p-4 opacity-40">
				<div class="w-2 h-2 rounded-full bg-secondary"></div>
				<div></div>
				<div></div>
				<div class="w-2 h-2 rounded-full bg-secondary"></div>
			</div>
		</div>

		<!-- Subtle Blobs -->
		<div
			class="absolute top-1/3 left-1/4 w-[500px] h-[500px] bg-secondary/10 rounded-full blur-[150px] animate-pulse"
		></div>
		<div
			class="absolute bottom-1/3 right-1/4 w-[500px] h-[500px] bg-tertiary/10 rounded-full blur-[150px] animate-pulse [animation-delay:3s]"
		></div>
	</div>
</div>

<!-- Background Accents -->
<div
	class="fixed top-0 left-0 w-full h-1/2 -z-5 bg-gradient-to-b from-secondary/[0.05] to-transparent pointer-events-none"
></div>

<main
	class="min-h-screen flex flex-col items-center justify-center p-6 sm:p-12 max-w-6xl mx-auto lg:flex-row gap-8 xl:gap-24 pt-6 pb-24 relative"
>
	<!-- Left Side: Compact Value Prop -->
	<div class="flex-1 text-center lg:text-left space-y-4">
		<div class="mb-4">
			<h1
				class="text-6xl font-black font-headline text-on-surface tracking-tighter leading-[1.1] flex flex-col lg:block"
			>
				<span
					class="flex items-center justify-center lg:justify-start gap-4 mb-2"
				>
					<div
						class="w-14 h-14 bg-white/90 dark:bg-surface-container-high/90 backdrop-blur-2xl rounded-2xl shadow-2xl flex items-center justify-center p-2.5 transform rotate-12 transition-all duration-500 border border-white/40 shadow-secondary/10"
					>
						<img
							src="/favicon.svg"
							alt="Meeple Logo"
							class="w-full h-full object-contain"
						/>
					</div>
				</span>
				<div class="block">
					<span>Join</span> the
					<span class="text-primary italic">table.</span>
				</div>
			</h1>
		</div>

		<div class="space-y-3 max-w-xs mx-auto lg:mx-0">
			<div class="flex items-center gap-3 group">
				<div
					class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center group-hover:scale-110 transition-transform"
				>
					<span class="material-symbols-outlined text-primary text-sm"
						>group</span
					>
				</div>
				<p class="text-on-surface-variant font-bold text-xs">
					Join 10k+ board game enthusiasts
				</p>
			</div>
			<div class="flex items-center gap-3 group">
				<div
					class="w-8 h-8 rounded-full bg-secondary/10 flex items-center justify-center group-hover:scale-110 transition-transform"
				>
					<span
						class="material-symbols-outlined text-secondary text-sm"
						>inventory_2</span
					>
				</div>
				<p class="text-on-surface-variant font-bold text-xs">
					Manage and track your collection
				</p>
			</div>
		</div>
	</div>

	<!-- Right Side: Unified Form -->
	<div class="w-full max-w-lg pb-12 lg:pb-0">
		<div class="space-y-4 relative">
			<!-- Glass backdrop for the form area -->
			<div
				class="absolute -inset-8 bg-white/[0.02] dark:bg-black/[0.02] backdrop-blur-sm -z-10 rounded-[3rem] border border-white/5 xl:block hidden"
			></div>

			<form onsubmit={handleSubmit} class="space-y-3.5">
				{#if error}
					<div
						class="text-sm text-error bg-error-container/40 backdrop-blur-md rounded-2xl px-5 py-4 border border-error/5 flex items-center gap-3"
					>
						<span class="material-symbols-outlined text-[20px]"
							>error</span
						>
						{error}
					</div>
				{/if}

				<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
					<div class="space-y-1.5 px-0.5">
						<label
							for="email"
							class="text-[9px] font-black text-on-surface-variant uppercase tracking-[.2em] pl-1"
							>Email</label
						>
						<input
							id="email"
							type="email"
							placeholder="Your email"
							bind:value={email}
							required
							autocomplete="email"
							class="w-full bg-surface-container-highest/60 backdrop-blur-md border border-outline-variant/30 rounded-2xl px-5 py-3.5 text-on-surface focus:ring-4 focus:ring-primary/10 focus:border-primary/50 focus:outline-none font-body text-sm transition-all"
						/>
					</div>

					<div class="space-y-1.5 px-0.5">
						<label
							for="username"
							class="text-[9px] font-black text-on-surface-variant uppercase tracking-[.2em] pl-1"
							>Username</label
						>
						<div class="relative">
							<input
								id="username"
								type="text"
								placeholder="Nickname"
								bind:value={username}
								oninput={(e) => {
									username = (
										e.target as HTMLInputElement
									).value.toLowerCase();
									touched.username = true;
									onUsernameInput();
								}}
								required
								autocomplete="username"
								class="w-full bg-surface-container-highest/60 backdrop-blur-md border border-outline-variant/30 rounded-2xl px-5 py-3.5 pr-12 text-on-surface focus:ring-4 focus:ring-primary/10 focus:border-primary/50 focus:outline-none font-body text-sm transition-all"
							/>
							{#if usernameStatus === "available"}
								<span
									class="absolute right-4 top-1/2 -translate-y-1/2 text-tertiary material-symbols-outlined text-[20px]"
									>check_circle</span
								>
							{:else if usernameStatus === "taken" || (touched.username && !isUsernameValid)}
								<span
									class="absolute right-4 top-1/2 -translate-y-1/2 text-error material-symbols-outlined text-[20px]"
									>cancel</span
								>
							{/if}
						</div>
					</div>
				</div>

				<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
					<div class="space-y-1.5 px-0.5">
						<label
							for="password"
							class="text-[9px] font-black text-on-surface-variant uppercase tracking-[.2em] pl-1"
							>Secret Key</label
						>
						<input
							id="password"
							type="password"
							placeholder="Min 8 chars"
							bind:value={password}
							oninput={() => (touched.password = true)}
							required
							autocomplete="new-password"
							class="w-full bg-surface-container-highest/60 backdrop-blur-md border border-outline-variant/30 rounded-2xl px-5 py-3.5 text-on-surface focus:ring-4 focus:ring-primary/10 focus:border-primary/50 focus:outline-none font-body text-sm transition-all"
						/>
						{#if password.length > 0}
							<div
								class="mt-2 h-1 bg-surface-container-highest/40 rounded-full overflow-hidden"
							>
								<div
									class="h-full rounded-full transition-all duration-700 {strengthColors[
										passwordStrength()
									]} {strengthWidths[passwordStrength()]}"
								></div>
							</div>
						{/if}
					</div>

					<div class="space-y-1.5 px-0.5">
						<label
							for="confirm"
							class="text-[9px] font-black text-on-surface-variant uppercase tracking-[.2em] pl-1"
							>Confirm Key</label
						>
						<input
							id="confirm"
							type="password"
							placeholder="Repeat"
							bind:value={confirmPassword}
							oninput={() => (touched.confirmPassword = true)}
							required
							autocomplete="new-password"
							class="w-full bg-surface-container-highest/60 backdrop-blur-md border border-outline-variant/30 rounded-2xl px-5 py-3.5 text-on-surface focus:ring-4 focus:ring-primary/10 focus:border-primary/50 focus:outline-none font-body text-sm transition-all"
						/>
					</div>
				</div>

				<div class="pt-8">
					<Button
						type="submit"
						{loading}
						size="lg"
						fullWidth
						disabled={!canSubmit}
					>
						Create Profile
					</Button>
				</div>

				<div class="pt-4 text-center">
					<p class="text-sm text-on-surface-variant font-medium">
						Already a player?
						<a
							href="/auth/login"
							class="text-primary font-black hover:underline px-1"
							>Sign In</a
						>
					</p>
				</div>

				<div class="relative flex items-center gap-4 py-5">
					<div class="flex-1 h-px bg-outline-variant/20"></div>
					<span
						class="text-[8px] text-on-surface-variant font-black uppercase tracking-[.3em]"
						>Quick Connect</span
					>
					<div class="flex-1 h-px bg-outline-variant/20"></div>
				</div>

				<GoogleButton redirectTo="/" onError={(msg) => (error = msg)} />
			</form>
		</div>
	</div>
</main>

<style>
	@keyframes float {
		0%,
		100% {
			transform: translateY(0) rotate(-12deg);
		}
		50% {
			transform: translateY(-20px) rotate(-8deg);
		}
	}
	@keyframes float-slow {
		0%,
		100% {
			transform: translateY(0) rotate(6deg);
		}
		50% {
			transform: translateY(-15px) rotate(10deg);
		}
	}
	.animate-float {
		animation: float 7s ease-in-out infinite;
	}
	.animate-float-slow {
		animation: float-slow 9s ease-in-out infinite;
	}
</style>
