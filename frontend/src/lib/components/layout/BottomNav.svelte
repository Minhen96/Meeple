<script lang="ts">
	import { page } from '$app/stores';

	const navItems = [
		{ href: '/', icon: 'home', label: 'Home' },
		{ href: '/library', icon: 'menu_book', label: 'Library' },
		{ href: '/events', icon: 'event', label: 'Events' },
		{ href: '/profile', icon: 'person', label: 'Profile' }
	];

	function isActive(href: string): boolean {
		if (href === '/') return $page.url.pathname === '/';
		return $page.url.pathname.startsWith(href);
	}
</script>

<nav
	class="fixed bottom-0 left-0 w-full z-50 bg-[#F8F9FA]/80 backdrop-blur-xl rounded-t-[2rem] shadow-[0_-8px_24px_rgba(0,0,0,0.04)]"
>
	<div class="flex justify-around items-center px-4 pb-safe pt-2 max-w-lg mx-auto">
		{#each navItems as item}
			<a
				href={item.href}
				class="flex flex-col items-center gap-0.5 p-3 transition-all spring-bounce duration-300 rounded-full {isActive(item.href)
					? 'bg-primary-container/20 text-primary'
					: 'text-on-surface-variant hover:text-secondary'}"
				aria-current={isActive(item.href) ? 'page' : undefined}
			>
				<span
					class="material-symbols-outlined text-[24px]"
					style={isActive(item.href) ? "font-variation-settings: 'FILL' 1;" : ''}
				>
					{item.icon}
				</span>
				<span class="text-[10px] font-label font-bold">{item.label}</span>
			</a>
		{/each}
	</div>
</nav>
