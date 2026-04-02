<script lang="ts">
	import Button from "$lib/components/ui/Button.svelte";
	import GoogleButton from "$lib/components/ui/GoogleButton.svelte";
	import { api, ApiRequestError } from "$lib/api/client";
	import { goto } from "$app/navigation";
	import { page } from "$app/stores";
	import AppBar from "$lib/components/layout/AppBar.svelte";

	let emailOrUsername = $state("");
	let password = $state("");
	let showPassword = $state(false);
	let loading = $state(false);
	let error = $state("");

	const redirectTo = $derived($page.url.searchParams.get("redirect") ?? "/");

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = "";
		loading = true;

		try {
			await api.post("/api/v1/auth/login", { emailOrUsername, password });
			window.location.href = redirectTo;
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
	<title>Log In — Meeple</title>
</svelte:head>

<!-- Premium Game Board Background -->
<div class="fixed inset-0 -z-10 bg-[#ebe8e2] dark:bg-surface overflow-hidden">
	<!-- Base Gradients -->
	<div
		class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-from),_transparent_70%),_radial-gradient(circle_at_bottom_left,_var(--tw-gradient-to),_transparent_70%)] from-primary/30 to-secondary/30 opacity-90"
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
		<!-- Floating Card -->
		<div
			class="absolute top-[15%] left-[10%] w-32 h-44 bg-white/5 dark:bg-white/10 backdrop-blur-3xl rounded-xl border border-white/10 shadow-2xl transform rotate-12 animate-float opacity-40 hidden lg:block overflow-hidden"
		>
			<div
				class="absolute top-2 left-2 w-6 h-6 rounded-full bg-primary/20"
			></div>
			<div class="mt-12 px-4 space-y-2">
				<div class="h-2 w-full bg-white/10 rounded"></div>
				<div class="h-2 w-2/3 bg-white/10 rounded"></div>
			</div>
		</div>

		<!-- Floating Die -->
		<div
			class="absolute bottom-[20%] right-[15%] w-20 h-20 bg-primary/10 backdrop-blur-2xl rounded-2xl border border-primary/20 shadow-xl transform -rotate-12 animate-float-slow hidden md:flex items-center justify-center"
		>
			<div class="grid grid-cols-2 gap-2 p-4 opacity-40">
				<div class="w-2 h-2 rounded-full bg-primary"></div>
				<div class="w-2 h-2 rounded-full bg-primary"></div>
				<div class="w-2 h-2 rounded-full bg-primary"></div>
				<div class="w-2 h-2 rounded-full bg-primary"></div>
			</div>
		</div>

		<!-- Subtle Blobs -->
		<div
			class="absolute top-1/4 right-1/4 w-96 h-96 bg-primary/10 rounded-full blur-[120px] animate-pulse"
		></div>
		<div
			class="absolute bottom-1/4 left-1/4 w-96 h-96 bg-secondary/10 rounded-full blur-[120px] animate-pulse [animation-delay:2s]"
		></div>
	</div>
</div>

<!-- Background Accents -->
<div
	class="fixed top-0 left-0 w-full h-1/2 -z-5 bg-gradient-to-b from-primary/[0.05] to-transparent pointer-events-none"
></div>

<main
	class="min-h-screen flex flex-col items-center justify-center p-6 sm:p-12 max-w-6xl mx-auto md:flex-row gap-8 lg:gap-16 overflow-hidden relative"
>
	<!-- Left Side: Compact Brand Hero -->
	<div class="flex-1 text-center md:text-left space-y-2 pt-4 md:pt-0">
		<div
			class="flex items-center justify-center md:justify-start gap-4 mb-4"
		>
			<div
				class="w-16 h-16 bg-white/90 dark:bg-surface-container-high/90 backdrop-blur-2xl rounded-2xl shadow-2xl flex items-center justify-center p-3 transform -rotate-6 hover:rotate-0 transition-all duration-500 border border-white/40 shadow-primary/10"
			>
				<img
					src="/favicon.svg"
					alt="Meeple Logo"
					class="w-full h-full object-contain"
				/>
			</div>
			<h1
				class="text-6xl sm:text-7xl font-black font-headline text-on-surface tracking-tighter leading-none"
			>
				<span class="text-primary italic">Meeple</span>
			</h1>
		</div>

		<div class="space-y-4">
			<h4
				class="text-3xl sm:text-4xl font-black font-headline text-on-surface tracking-tight opacity-90"
			>
				Boardgame app
			</h4>
			<p
				class="text-base text-on-surface-variant font-medium max-w-sm mx-auto md:mx-0 opacity-60 leading-relaxed"
			>
				Welcome back to the world's most premium board game community.
				Discover, track, and play.
			</p>
		</div>
	</div>

	<!-- Right Side: The Form -->
	<div class="w-full max-w-md pb-12 md:pb-0">
		<div class="space-y-4 relative">
			<!-- Glass backdrop for the form area itself to pop -->
			<div
				class="absolute -inset-8 bg-white/[0.02] dark:bg-black/[0.02] backdrop-blur-sm -z-10 rounded-[3rem] border border-white/5 lg:block hidden"
			></div>

			<form onsubmit={handleSubmit} class="space-y-5">
				{#if error}
					<div
						class="text-sm text-error bg-error-container/40 backdrop-blur-md rounded-2xl px-5 py-4 flex items-center gap-3 border border-error/5"
					>
						<span class="material-symbols-outlined text-[20px]"
							>error</span
						>
						{error}
					</div>
				{/if}

				<div class="space-y-1.5 px-0.5">
					<label
						for="email"
						class="text-[10px] font-black text-on-surface-variant uppercase tracking-[.2em] pl-1"
						>Identity</label
					>
					<input
						id="email"
						type="text"
						placeholder="Email or username"
						bind:value={emailOrUsername}
						required
						autocomplete="username"
						class="w-full bg-surface-container-highest/60 backdrop-blur-md border border-outline-variant/30 rounded-2xl px-5 py-3.5 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-4 focus:ring-primary/10 focus:border-primary/50 focus:outline-none font-body text-sm transition-all"
					/>
				</div>

				<div class="space-y-1.5 px-0.5">
					<div class="flex justify-between items-center pl-1">
						<label
							for="password"
							class="text-[10px] font-black text-on-surface-variant uppercase tracking-[.2em]"
							>Password</label
						>
						<a
							href="/auth/forgot-password"
							class="text-[10px] text-primary font-black uppercase tracking-widest hover:underline"
							>Forget password?</a
						>
					</div>
					<div class="relative">
						<input
							id="password"
							type={showPassword ? "text" : "password"}
							placeholder="Your password"
							bind:value={password}
							required
							autocomplete="current-password"
							class="w-full bg-surface-container-highest/60 backdrop-blur-md border border-outline-variant/30 rounded-2xl px-5 py-3.5 pr-14 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-4 focus:ring-primary/10 focus:border-primary/50 focus:outline-none font-body text-sm transition-all"
						/>
						<button
							type="button"
							onclick={() => (showPassword = !showPassword)}
							class="absolute right-4 top-1/2 -translate-y-1/2 text-on-surface-variant hover:text-primary transition-colors"
							aria-label="Toggle password visibility"
						>
							<span class="material-symbols-outlined text-[22px]">
								{showPassword ? "visibility_off" : "visibility"}
							</span>
						</button>
					</div>
				</div>

				<div class="pt-6">
					<Button type="submit" {loading} size="lg" fullWidth
						>Log In</Button
					>
				</div>

				<div class="pt-6 text-center">
					<p class="text-sm text-on-surface-variant font-medium">
						New player?
						<a
							href="/auth/register"
							class="text-primary font-black hover:underline px-1"
							>Join Community</a
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

				<GoogleButton {redirectTo} onError={(msg) => (error = msg)} />
			</form>
		</div>
	</div>
</main>

<style>
	@keyframes float {
		0%,
		100% {
			transform: translateY(0) rotate(12deg);
		}
		50% {
			transform: translateY(-20px) rotate(15deg);
		}
	}
	@keyframes float-slow {
		0%,
		100% {
			transform: translateY(0) rotate(-12deg);
		}
		50% {
			transform: translateY(-15px) rotate(-8deg);
		}
	}
	.animate-float {
		animation: float 6s ease-in-out infinite;
	}
	.animate-float-slow {
		animation: float-slow 8s ease-in-out infinite;
	}
</style>
