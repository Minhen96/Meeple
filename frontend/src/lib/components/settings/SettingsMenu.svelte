<script lang="ts">
	// Settings menu (SCREENS_AND_STATES section 11.1; FEATURES_COMPLETE section 10.1). The whole
	// /settings screen on phones; from lg the persistent left column of the settings two-pane
	// layout, with the row of the screen on the right highlighted.
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { toast } from 'svelte-sonner';
	import { usersApi } from '$lib/api/users';
	import { ApiRequestError } from '$lib/api/client';
	import SetupStatusModal from '$lib/components/admin/SetupStatusModal.svelte';
	import { LANGUAGE_NAMES, changeLanguage } from '$lib/components/layout/language';
	import { LOCALES, errorMessage, locale, m, type Locale, type MessageKey } from '$lib/i18n';
	import { logout } from '$lib/session';
	import { currentUser, setUser } from '$lib/stores/auth';
	import { isActiveSettingsHref } from './settingsNav';

	const APP_VERSION = '1.0.0';
	const TERMS_URL = (import.meta.env.VITE_TERMS_URL as string | undefined) || 'https://meeple-hearth.com/terms';
	const PRIVACY_URL =
		(import.meta.env.VITE_PRIVACY_URL as string | undefined) || 'https://meeple-hearth.com/privacy';
	const FEEDBACK_EMAIL =
		(import.meta.env.VITE_FEEDBACK_EMAIL as string | undefined) || 'feedback@meeple-hearth.com';

	let showSetupModal = $state(false);
	let exporting = $state(false);
	let savingLanguage = $state(false);

	interface Item {
		label: MessageKey;
		icon: string;
		href?: string;
		external?: boolean;
		action?: () => void;
		danger?: boolean;
		disabled?: boolean;
		detail?: string;
	}

	async function handleLogout() {
		await logout();
		void goto('/auth/login');
	}

	async function requestExport() {
		exporting = true;
		try {
			await usersApi.requestExport();
			toast.success(m('account.export.requested'));
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : null));
		} finally {
			exporting = false;
		}
	}

	async function selectLanguage(next: Locale) {
		savingLanguage = true;
		try {
			await changeLanguage(next, {
				save: (l) => usersApi.updateMe({ preferredLanguage: l }),
				onSaved: (user) => setUser(user)
			});
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR'));
		} finally {
			savingLanguage = false;
		}
	}

	const accountItems = $derived<Item[]>([
		{ label: 'account.settings.editProfile', icon: 'person', href: '/settings/profile' },
		{ label: 'account.settings.changeEmail', icon: 'alternate_email', href: '/settings/change-email' },
		...($currentUser?.hasPassword === false
			? []
			: [{ label: 'account.settings.changePassword' as MessageKey, icon: 'lock', href: '/settings/password' }]),
		{ label: 'account.settings.bggImport', icon: 'cloud_download', href: '/settings/bgg' },
		{ label: 'account.settings.sessions', icon: 'devices', href: '/settings/sessions' },
		{
			label: 'account.settings.exportData',
			icon: 'download',
			action: requestExport,
			detail: exporting ? m('common.loading') : undefined
		},
		{ label: 'account.settings.deleteAccount', icon: 'delete', href: '/settings/delete-account', danger: true }
	]);

	const managementItems: Item[] = [
		{ label: 'account.settings.reviewQueue', icon: 'rate_review', href: '/admin/rulebooks' },
		{ label: 'account.settings.systemHealth', icon: 'monitoring', href: '/admin/health' },
		{ label: 'account.settings.rulesImport', icon: 'settings_suggest', action: () => (showSetupModal = true) },
		{ label: 'account.settings.promoteAdmin', icon: 'person_add', href: '/settings/management' }
	];

	const sections = $derived<{ title: MessageKey; items: Item[] }[]>([
		{ title: 'account.settings.sectionAccount', items: accountItems },
		...($currentUser?.isAdmin ? [{ title: 'account.settings.sectionManagement' as MessageKey, items: managementItems }] : []),
		{
			title: 'account.settings.sectionNotifications',
			items: [
				{ label: 'account.settings.notificationPrefs', icon: 'notifications', href: '/settings/notifications' },
				{ label: 'account.settings.quietHours', icon: 'bedtime', href: '/settings/notifications#quiet-hours' }
			]
		},
		{
			title: 'account.settings.sectionPrivacy',
			items: [
				{
					label: 'account.settings.privacy',
					icon: 'shield_person',
					disabled: true,
					detail: m('common.comingSoon')
				}
			]
		},
		{
			title: 'account.settings.sectionAbout',
			items: [
				{ label: 'account.settings.version', icon: 'info', detail: APP_VERSION },
				{ label: 'account.settings.terms', icon: 'gavel', href: TERMS_URL, external: true },
				{ label: 'account.settings.privacyPolicy', icon: 'policy', href: PRIVACY_URL, external: true },
				{ label: 'account.settings.feedback', icon: 'feedback', href: `mailto:${FEEDBACK_EMAIL}`, external: true }
			]
		}
	]);

	const themes: { key: MessageKey; active: boolean }[] = [
		{ key: 'account.settings.themeLight', active: true },
		{ key: 'account.settings.themeDark', active: false },
		{ key: 'account.settings.themeSystem', active: false }
	];
</script>

{#snippet row(item: Item)}
	{@const tone = item.disabled
		? 'text-on-surface-variant/50'
		: item.danger
			? 'text-error'
			: 'text-on-surface'}
	{#if item.href && !item.disabled}
		{@const active = isActiveSettingsHref(page.url.pathname, item.href)}
		<a
			href={item.href}
			target={item.external ? '_blank' : undefined}
			rel={item.external ? 'noopener noreferrer' : undefined}
			aria-current={active ? 'page' : undefined}
			class="flex items-center gap-3 px-4 py-3.5 rounded-lg transition-colors {active
				? 'bg-primary-fixed text-on-primary-fixed'
				: `bg-surface-container-lowest hover:bg-surface-container ${tone}`}"
		>
			<span
				class="material-symbols-outlined text-[20px] {active
					? 'text-primary icon-filled'
					: item.danger
						? 'text-error'
						: 'text-on-surface-variant'}">{item.icon}</span
			>
			<span class="flex-1 text-sm {active ? 'font-bold' : 'font-medium'}">{m(item.label)}</span>
			<span class="material-symbols-outlined text-[16px] text-on-surface-variant"
				>{item.external ? 'open_in_new' : 'chevron_right'}</span
			>
		</a>
	{:else}
		<button
			type="button"
			disabled={item.disabled || !item.action}
			onclick={() => item.action?.()}
			class="w-full flex items-center gap-3 px-4 py-3.5 rounded-lg bg-surface-container-lowest transition-colors text-left disabled:cursor-default {item.action
				? 'hover:bg-surface-container'
				: ''} {tone}"
		>
			<span class="material-symbols-outlined text-[20px] text-on-surface-variant">{item.icon}</span>
			<span class="flex-1 text-sm">{m(item.label)}</span>
			{#if item.detail}
				<span class="text-xs text-on-surface-variant">{item.detail}</span>
			{:else if item.action}
				<span class="material-symbols-outlined text-[16px] text-on-surface-variant">chevron_right</span>
			{/if}
		</button>
	{/if}
{/snippet}

<div class="space-y-6">
	{#each sections as section (section.title)}
		<section>
			<h3 class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant px-1 mb-2">
				{m(section.title)}
			</h3>
			<div class="bg-surface-container-low rounded-xl overflow-hidden p-1 space-y-1">
				{#each section.items as item (item.label)}
					{@render row(item)}
				{/each}
			</div>
		</section>

		{#if section.title === 'account.settings.sectionPrivacy'}
			<section>
				<h3 class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant px-1 mb-2">
					{m('account.settings.sectionLanguage')}
				</h3>
				<div class="bg-surface-container-low rounded-xl p-1 flex gap-1" role="radiogroup" aria-label={m('account.settings.language')}>
					{#each LOCALES as option (option)}
						<button
							type="button"
							role="radio"
							aria-checked={$locale === option}
							disabled={savingLanguage}
							onclick={() => selectLanguage(option)}
							lang={option}
							class="flex-1 py-3 rounded-lg text-sm font-bold transition-colors {$locale === option
								? 'bg-primary text-on-primary'
								: 'bg-surface-container-lowest text-on-surface hover:bg-surface-container'}"
						>
							{LANGUAGE_NAMES[option]}
						</button>
					{/each}
				</div>
			</section>

			<section>
				<h3 class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant px-1 mb-2">
					{m('account.settings.sectionAppearance')}
				</h3>
				<div class="bg-surface-container-low rounded-xl p-1 flex gap-1" role="radiogroup" aria-label={m('account.settings.theme')}>
					{#each themes as theme (theme.key)}
						<button
							type="button"
							role="radio"
							aria-checked={theme.active}
							disabled={!theme.active}
							class="flex-1 py-3 rounded-lg text-sm font-bold {theme.active
								? 'bg-primary text-on-primary'
								: 'bg-surface-container-lowest text-on-surface-variant/50 cursor-not-allowed'}"
						>
							{m(theme.key)}
						</button>
					{/each}
				</div>
				<p class="text-xs text-on-surface-variant px-1 mt-2">{m('account.settings.themeHint')}</p>
			</section>
		{/if}
	{/each}

	<button
		onclick={handleLogout}
		class="w-full text-center py-3.5 rounded-lg text-error font-semibold text-sm hover:bg-error/10 transition-colors"
	>
		{m('account.settings.logout')}
	</button>
</div>

{#if showSetupModal}
	<SetupStatusModal onClose={() => (showSetupModal = false)} />
{/if}
