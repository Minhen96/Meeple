<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	const navItems = [
		{ href: '/', icon: 'home', label: 'Home' },
		{ href: '/library', icon: 'library_books', label: 'Library' },
		{ href: null as string | null, icon: 'add', label: '', isFab: true },
		{ href: '/events', icon: 'event', label: 'Events' },
		{ href: '/profile', icon: 'person', label: 'Profile' }
	];

	function isActive(href: string | null): boolean {
		if (!href) return false;
		if (href === '/') return $page.url.pathname === '/';
		return $page.url.pathname.startsWith(href);
	}

	function handleFab() {
		// Opens a create bottom sheet — currently navigates to posts/create
		goto('/posts/create');
	}
</script>

<nav
	class="fixed bottom-0 w-full z-50 bg-[#F8F9FA]/80 backdrop-blur-xl shadow-[0_-4px_24px_rgba(0,0,0,0.04)]"
>
	<div class="flex items-end justify-around px-4 pb-safe max-w-lg mx-auto">
		{#each navItems as item}
			{#if item.isFab}
				<button
					onclick={handleFab}
					class="relative -top-5 w-14 h-14 bg-gradient-to-br from-primary to-primary-container rounded-full flex items-center justify-center shadow-[0_8px_24px_rgba(137,81,0,0.30)] hover:scale-110 active:scale-95 transition-all"
					aria-label="Create"
				>
					<span class="material-symbols-outlined text-on-primary text-2xl">add</span>
				</button>
			{:else}
				<a
					href={item.href}
					class="flex flex-col items-center py-3 gap-0.5 min-w-[48px] transition-colors {isActive(item.href) ? 'text-primary' : 'text-on-surface-variant'}"
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
			{/if}
		{/each}
	</div>
</nav>
