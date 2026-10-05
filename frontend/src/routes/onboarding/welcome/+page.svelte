<script lang="ts">
	// Step 1 — Welcome (SCREENS_AND_STATES section 3.2). Users returning mid-onboarding skip
	// straight to step 2. "Get Started" saves the detected language and time zone.
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import Button from '$lib/components/ui/Button.svelte';
	import { usersApi } from '$lib/api/users';
	import { getLocale, m, type MessageKey } from '$lib/i18n';
	import { setUser } from '$lib/stores/auth';
	import { page } from '$app/state';
	import { browserTimezone, hasSeenWelcome, markWelcomeSeen } from '../onboarding';

	let starting = $state(false);

	const features: { icon: string; title: MessageKey; desc: MessageKey }[] = [
		{ icon: 'library_books', title: 'account.welcome.libraryTitle', desc: 'account.welcome.libraryBody' },
		{ icon: 'event', title: 'account.welcome.eventsTitle', desc: 'account.welcome.eventsBody' },
		{ icon: 'groups', title: 'account.welcome.matchTitle', desc: 'account.welcome.matchBody' }
	];

	onMount(() => {
		const userId: string | undefined = page.data.user?.id;
		if (userId && hasSeenWelcome(userId)) {
			void goto('/onboarding/profile', { replaceState: true });
		}
	});

	async function start() {
		starting = true;
		const userId: string | undefined = page.data.user?.id;
		if (userId) markWelcomeSeen(userId);
		try {
			setUser(await usersApi.updateMe({ preferredLanguage: getLocale(), timezone: browserTimezone() }));
		} catch {
			// Best effort: language and time zone can be set later in Settings
		} finally {
			starting = false;
			void goto('/onboarding/profile');
		}
	}
</script>

<svelte:head><title>{m('account.welcome.title')} — {m('common.appName')}</title></svelte:head>

<div class="flex flex-col items-center text-center py-12 space-y-8">
	<div class="flex flex-col items-center">
		<div class="w-20 h-20 bg-surface-container-lowest rounded-3xl shadow-lg flex items-center justify-center p-4 -rotate-6 mb-4">
			<img src="/favicon.svg" alt="" class="w-full h-full object-contain" />
		</div>
		<h1 class="text-4xl font-extrabold tracking-tight font-headline text-primary">{m('common.appName')}</h1>
		<p class="mt-3 text-on-surface-variant">{m('account.welcome.tagline')}</p>
	</div>

	<div class="w-full space-y-4 text-left">
		{#each features as feature (feature.title)}
			<div class="flex items-start gap-4 bg-surface-container-low rounded-xl p-4">
				<span class="material-symbols-outlined text-primary text-2xl mt-0.5" aria-hidden="true">{feature.icon}</span>
				<div>
					<p class="font-semibold text-on-surface">{m(feature.title)}</p>
					<p class="text-sm text-on-surface-variant">{m(feature.desc)}</p>
				</div>
			</div>
		{/each}
	</div>

	<Button fullWidth loading={starting} onclick={start}>{m('account.welcome.start')}</Button>
</div>
