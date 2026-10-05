<script lang="ts">
	// Login (SCREENS_AND_STATES section 2.1) plus reactivation of an account deleted less than
	// 30 days ago (FEATURES_COMPLETE section 1.6): login answers 403 ACCOUNT_DELETED and the user
	// can restore the account with the same credentials (or Google sign-in).
	import { page } from '$app/state';
	import Button from '$lib/components/ui/Button.svelte';
	import GoogleButton from '$lib/components/ui/GoogleButton.svelte';
	import { authApi } from '$lib/api/auth';
	import { errorMessage, m } from '$lib/i18n';
	import { safeRedirectPath } from '$lib/utils/redirect';
	import { classifyLoginError, type LoginFailure } from './loginErrors';

	let emailOrUsername = $state('');
	let password = $state('');
	let showPassword = $state(false);
	let loading = $state(false);
	let failure = $state<LoginFailure | null>(null);
	let googleMessage = $state('');
	/** Set when Google sign-in hit a deleted account: reactivation uses this credential. */
	let deletedGoogleCredential = $state<string | null>(null);
	let reactivating = $state(false);
	let resent = $state(false);
	// Where to go after login (set by the auth guard); only same-origin paths.
	const redirectTo = $derived(safeRedirectPath(page.url.searchParams.get('redirect')));
	const justDeleted = $derived(page.url.searchParams.get('deleted') === '1');
	const showDeleted = $derived(failure?.kind === 'deleted' || deletedGoogleCredential !== null);

	const errorText = $derived.by(() => {
		if (googleMessage) return googleMessage;
		if (!failure) return '';
		switch (failure.kind) {
			case 'invalidCredentials':
				return m('account.login.invalidCredentials');
			case 'locked':
				return m('account.login.locked');
			case 'rateLimited':
				return failure.retryAfterSeconds
					? m('account.login.rateLimited', { seconds: failure.retryAfterSeconds })
					: m('errors.rateLimited');
			case 'other':
				return errorMessage(failure.code);
			default:
				return '';
		}
	});

	function reset() {
		failure = null;
		googleMessage = '';
		deletedGoogleCredential = null;
		resent = false;
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		reset();
		loading = true;
		try {
			await authApi.login(emailOrUsername, password);
			window.location.href = redirectTo;
		} catch (err) {
			failure = classifyLoginError(err);
		} finally {
			loading = false;
		}
	}

	async function reactivate() {
		reactivating = true;
		try {
			if (deletedGoogleCredential) {
				await authApi.reactivate({ googleIdToken: deletedGoogleCredential });
			} else {
				await authApi.reactivate({ emailOrUsername, password });
			}
			window.location.href = redirectTo;
		} catch (err) {
			deletedGoogleCredential = null;
			const next = classifyLoginError(err);
			failure = next.kind === 'deleted' ? { kind: 'other', code: 'ACCOUNT_DELETED' } : next;
		} finally {
			reactivating = false;
		}
	}

	async function resendVerification() {
		try {
			await authApi.resendVerification(emailOrUsername.trim());
		} catch {
			// The answer never reveals whether the address exists
		}
		resent = true;
	}
</script>

<svelte:head>
	<title>{m('account.login.title')} — {m('common.appName')}</title>
</svelte:head>

<!-- Game board backdrop -->
<div class="fixed inset-0 -z-10 bg-auth-backdrop dark:bg-surface overflow-hidden">
	<div
		class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-from),_transparent_70%),_radial-gradient(circle_at_bottom_left,_var(--tw-gradient-to),_transparent_70%)] from-primary/30 to-secondary/30 opacity-90"
	></div>
	<div
		class="absolute inset-0 opacity-[0.06] dark:opacity-[0.08] [background-image:radial-gradient(circle_at_center,_theme(colors.on-surface)_1px,transparent_1px)] [background-size:32px_32px]"
	></div>
	<div class="absolute inset-0 pointer-events-none">
		<div class="absolute top-1/4 right-1/4 w-96 h-96 bg-primary/10 rounded-full blur-[120px] animate-pulse"></div>
		<div
			class="absolute bottom-1/4 left-1/4 w-96 h-96 bg-secondary/10 rounded-full blur-[120px] animate-pulse [animation-delay:2s]"
		></div>
	</div>
</div>

<main
	class="min-h-screen flex flex-col items-center justify-center p-6 sm:p-12 max-w-6xl mx-auto md:flex-row gap-8 lg:gap-16 overflow-hidden relative"
>
	<div class="flex-1 text-center md:text-left space-y-2 pt-4 md:pt-0">
		<div class="flex items-center justify-center md:justify-start gap-4 mb-4">
			<div
				class="w-16 h-16 bg-surface-container-lowest/90 backdrop-blur-2xl rounded-2xl shadow-2xl flex items-center justify-center p-3 transform -rotate-6 hover:rotate-0 transition-all duration-500 border border-white/10"
			>
				<img src="/favicon.svg" alt="" class="w-full h-full object-contain" />
			</div>
			<h1 class="text-6xl sm:text-7xl font-black font-headline text-on-surface tracking-tighter leading-none">
				<span class="text-primary italic">{m('common.appName')}</span>
			</h1>
		</div>
		<div class="space-y-4">
			<p class="text-3xl sm:text-4xl font-black font-headline text-on-surface tracking-tight opacity-90">
				{m('account.login.heroTitle')}
			</p>
			<p class="text-base text-on-surface-variant font-medium max-w-sm mx-auto md:mx-0 opacity-60 leading-relaxed">
				{m('account.login.heroBody')}
			</p>
		</div>
	</div>

	<div class="w-full max-w-md pb-12 md:pb-0">
		<div class="space-y-4">
			{#if justDeleted && !showDeleted}
				<div class="text-sm bg-surface-container-high rounded-2xl px-5 py-4 text-on-surface" role="status">
					{m('account.login.deletedNotice')}
				</div>
			{/if}

			{#if showDeleted}
				<div class="bg-secondary-container rounded-2xl px-5 py-4 space-y-3 text-on-secondary-container" role="alert">
					<p class="font-bold">{m('account.login.deletedTitle')}</p>
					<p class="text-sm">{m('account.login.deletedBody')}</p>
					<Button fullWidth loading={reactivating} onclick={reactivate}>{m('account.login.reactivate')}</Button>
				</div>
			{/if}

			<form onsubmit={handleSubmit} class="space-y-5">
				{#if errorText}
					<div
						class="text-sm text-error bg-error-container/40 backdrop-blur-md rounded-2xl px-5 py-4 flex items-center gap-3 border border-white/10"
						role="alert"
					>
						<span class="material-symbols-outlined text-[20px]">error</span>
						{errorText}
					</div>
				{/if}

				{#if failure?.kind === 'unverified'}
					<div class="text-sm bg-secondary-container text-on-secondary-container rounded-2xl px-5 py-4 space-y-2" role="alert">
						<p>{m('account.login.unverified')}</p>
						{#if resent}
							<p class="font-bold">{m('account.verify.resent')}</p>
						{:else if emailOrUsername.includes('@')}
							<button type="button" class="font-bold underline" onclick={resendVerification}>
								{m('account.login.resend')}
							</button>
						{:else}
							<a href="/auth/verify-email" class="font-bold underline">{m('account.login.resend')}</a>
						{/if}
					</div>
				{/if}

				<div class="space-y-1.5 px-0.5">
					<label for="email" class="text-[10px] font-black text-on-surface-variant uppercase tracking-[.2em] pl-1">
						{m('account.login.identityLabel')}
					</label>
					<input
						id="email"
						type="text"
						placeholder={m('account.login.identityPlaceholder')}
						bind:value={emailOrUsername}
						required
						autocomplete="username"
						class="w-full bg-surface-container-highest/60 backdrop-blur-md rounded-2xl px-5 py-3.5 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-2 focus:ring-primary/40 focus:outline-none font-body text-sm transition-all"
					/>
				</div>

				<div class="space-y-1.5 px-0.5">
					<div class="flex justify-between items-center pl-1">
						<label for="password" class="text-[10px] font-black text-on-surface-variant uppercase tracking-[.2em]">
							{m('account.login.passwordLabel')}
						</label>
						<a href="/auth/forgot-password" class="text-[10px] text-primary font-black uppercase tracking-widest hover:underline">
							{m('account.login.forgot')}
						</a>
					</div>
					<div class="relative">
						<input
							id="password"
							type={showPassword ? 'text' : 'password'}
							placeholder={m('account.login.passwordPlaceholder')}
							bind:value={password}
							required
							autocomplete="current-password"
							class="w-full bg-surface-container-highest/60 backdrop-blur-md rounded-2xl px-5 py-3.5 pr-14 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-2 focus:ring-primary/40 focus:outline-none font-body text-sm transition-all"
						/>
						<button
							type="button"
							onclick={() => (showPassword = !showPassword)}
							class="absolute right-4 top-1/2 -translate-y-1/2 text-on-surface-variant hover:text-primary transition-colors"
							aria-label={m('account.login.togglePassword')}
						>
							<span class="material-symbols-outlined text-[22px]">
								{showPassword ? 'visibility_off' : 'visibility'}
							</span>
						</button>
					</div>
				</div>

				<div class="pt-6">
					<Button type="submit" {loading} size="lg" fullWidth>
						{loading ? m('account.login.submitting') : m('account.login.submit')}
					</Button>
				</div>

				<div class="pt-6 text-center">
					<p class="text-sm text-on-surface-variant font-medium">
						{m('account.login.newPlayer')}
						<a href="/auth/register" class="text-primary font-black hover:underline px-1">{m('account.login.join')}</a>
					</p>
				</div>

				<div class="relative flex items-center gap-4 py-5">
					<div class="flex-1 h-px bg-outline-variant/20"></div>
					<span class="text-[8px] text-on-surface-variant font-black uppercase tracking-[.3em]">
						{m('account.login.quickConnect')}
					</span>
					<div class="flex-1 h-px bg-outline-variant/20"></div>
				</div>

				<GoogleButton
					{redirectTo}
					onError={(msg) => {
						reset();
						googleMessage = msg;
					}}
					onAccountDeleted={(credential) => {
						reset();
						deletedGoogleCredential = credential;
					}}
				/>
			</form>
		</div>
	</div>
</main>
