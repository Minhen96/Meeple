<script lang="ts">
	// Tablet rail (md, icons only) and desktop sidebar (lg+, icons + labels) — SCREENS_AND_STATES
	// section 16. Replaces the bottom nav and the top app bar's search / notifications from md up.
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { m } from '$lib/i18n';
	import { logout } from '$lib/session';
	import { currentUser } from '$lib/stores/auth';
	import { notificationCount } from '$lib/stores/notifications';
	import CreateMenu from './CreateMenu.svelte';
	import { SIDEBAR_NAV, badgeText, isNavActive, type NavItem } from './shell';

	const pathname = $derived(page.url.pathname);
	const settingsActive = $derived(isNavActive(pathname, '/settings'));
	const badge = $derived(badgeText($notificationCount));
	const userName = $derived($currentUser ? ($currentUser.displayName ?? $currentUser.username) : '');

	let loggingOut = $state(false);

	function accessibleName(item: NavItem): string {
		if (item.badge === 'notifications' && $notificationCount > 0) {
			return m('common.notificationsUnread', { count: $notificationCount });
		}
		return m(item.label);
	}

	async function handleLogout() {
		if (loggingOut) return;
		loggingOut = true;
		try {
			await logout();
			void goto('/auth/login');
		} finally {
			loggingOut = false;
		}
	}

	const focusRing =
		'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-surface-container-low';
</script>

<aside
	class="hidden md:flex fixed inset-y-0 left-0 z-50 w-rail lg:w-sidebar flex-col gap-6 bg-surface-container-low px-3 lg:px-4 py-6"
	data-testid="app-sidebar"
>
	<a
		href="/"
		class="flex items-center justify-center lg:justify-start gap-2.5 lg:px-2 rounded-full {focusRing}"
		aria-label={m('common.appName')}
	>
		<span
			class="w-10 h-10 shrink-0 bg-surface-container-lowest rounded-xl shadow-sm flex items-center justify-center p-2 -rotate-12 hover:rotate-0 transition-transform duration-300 motion-reduce:transition-none"
		>
			<img src="/favicon.svg" alt="" class="w-full h-full object-contain" />
		</span>
		<span class="hidden lg:inline font-headline text-primary font-black tracking-tighter text-2xl">
			{m('common.appName')}
		</span>
	</a>

	<CreateMenu />

	<nav aria-label={m('common.nav.label')} class="flex-1 min-h-0 overflow-y-auto hide-scrollbar -mx-1 px-1">
		<ul class="flex flex-col gap-1">
			{#each SIDEBAR_NAV as item (item.href)}
				{@const active = isNavActive(pathname, item.href)}
				<li>
					<a
						href={item.href}
						aria-current={active ? 'page' : undefined}
						aria-label={accessibleName(item)}
						title={m(item.label)}
						class="flex items-center justify-center lg:justify-start gap-3 rounded-full px-3 py-2.5 font-label font-bold text-sm transition-colors motion-reduce:transition-none {focusRing} {active
							? 'bg-primary-container/20 text-primary'
							: 'text-on-surface-variant hover:bg-surface-container hover:text-on-surface'}"
					>
						<span class="relative flex">
							<span class="material-symbols-outlined text-[24px]" class:icon-filled={active} aria-hidden="true">
								{item.icon}
							</span>
							{#if item.badge === 'notifications' && badge}
								<span
									class="absolute -top-1 -right-1.5 bg-error text-on-error text-[10px] font-bold rounded-full min-w-[16px] h-4 flex items-center justify-center px-1"
									aria-hidden="true"
									data-testid="sidebar-badge"
								>
									{badge}
								</span>
							{/if}
						</span>
						<span class="hidden lg:inline truncate">{m(item.label)}</span>
					</a>
				</li>
			{/each}
		</ul>
	</nav>

	{#if $currentUser}
		<section
			aria-label={m('common.nav.account')}
			class="flex flex-col lg:flex-row items-center gap-2 lg:gap-1 rounded-[1.5rem] lg:bg-surface-container lg:p-2"
		>
			<a
				href="/profile"
				class="flex items-center gap-3 min-w-0 lg:flex-1 rounded-full lg:pr-2 {focusRing}"
				title={userName}
			>
				<Avatar src={$currentUser.avatarUrl} name={userName} size="md" />
				<span class="hidden lg:block min-w-0">
					<span class="block truncate text-sm font-headline font-bold text-on-surface">{userName}</span>
					<span class="block truncate text-xs text-on-surface-variant">@{$currentUser.username}</span>
				</span>
			</a>
			<a
				href="/settings"
				aria-current={settingsActive ? 'page' : undefined}
				aria-label={m('common.nav.settings')}
				title={m('common.nav.settings')}
				class="w-10 h-10 shrink-0 rounded-full flex items-center justify-center transition-colors {focusRing} {settingsActive
					? 'bg-primary-container/20 text-primary'
					: 'text-on-surface-variant hover:bg-surface-container-high hover:text-on-surface'}"
			>
				<span class="material-symbols-outlined text-[22px]" class:icon-filled={settingsActive} aria-hidden="true"
					>settings</span
				>
			</a>
			<button
				type="button"
				onclick={handleLogout}
				disabled={loggingOut}
				aria-label={m('common.nav.logout')}
				title={m('common.nav.logout')}
				class="w-10 h-10 shrink-0 rounded-full flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high hover:text-error transition-colors disabled:opacity-50 {focusRing}"
			>
				<span class="material-symbols-outlined text-[22px]" aria-hidden="true">logout</span>
			</button>
		</section>
	{/if}
</aside>
