<script lang="ts">
	// Bottom navigation (SCREENS_AND_STATES section 1): Home, Library, [+], Events, Profile.
	// The centre "+" opens the create sheet.
	import { page } from '$app/state';
	import { m, type MessageKey } from '$lib/i18n';
	import CreateSheet from './CreateSheet.svelte';

	const navItems: { href: string; icon: string; label: MessageKey }[] = [
		{ href: '/', icon: 'home', label: 'common.nav.home' },
		{ href: '/library', icon: 'menu_book', label: 'common.nav.library' },
		{ href: '/events', icon: 'event', label: 'common.nav.events' },
		{ href: '/profile', icon: 'person', label: 'common.nav.profile' }
	];

	let createOpen = $state(false);

	function isActive(href: string): boolean {
		if (href === '/') return page.url.pathname === '/';
		return page.url.pathname.startsWith(href);
	}
</script>

{#snippet navLink(item: (typeof navItems)[number])}
	<a
		href={item.href}
		class="flex flex-col items-center gap-0.5 p-3 transition-all spring-bounce duration-300 rounded-full {isActive(
			item.href
		)
			? 'bg-primary-container/20 text-primary'
			: 'text-on-surface-variant hover:text-secondary'}"
		aria-current={isActive(item.href) ? 'page' : undefined}
	>
		<span class="material-symbols-outlined text-[24px]" class:icon-filled={isActive(item.href)}>
			{item.icon}
		</span>
		<span class="text-[10px] font-label font-bold">{m(item.label)}</span>
	</a>
{/snippet}

<nav
	aria-label={m('common.nav.label')}
	class="fixed bottom-0 left-0 w-full z-50 bg-surface/80 backdrop-blur-xl rounded-t-[2rem] shadow-[0_-8px_24px_rgba(0,0,0,0.04)]"
>
	<div class="flex justify-around items-center px-4 pb-safe pt-2 max-w-lg mx-auto">
		{@render navLink(navItems[0])}
		{@render navLink(navItems[1])}
		<button
			type="button"
			onclick={() => (createOpen = true)}
			class="-mt-8 w-14 h-14 bg-gradient-to-br from-primary to-primary-container text-on-primary rounded-full shadow-[0_8px_24px_rgba(137,81,0,0.35)] flex items-center justify-center transition-transform active:scale-95"
			aria-label={m('common.create.title')}
			aria-haspopup="dialog"
			aria-expanded={createOpen}
		>
			<span class="material-symbols-outlined text-2xl" aria-hidden="true">add</span>
		</button>
		{@render navLink(navItems[2])}
		{@render navLink(navItems[3])}
	</div>
</nav>

{#if createOpen}
	<CreateSheet onClose={() => (createOpen = false)} />
{/if}
