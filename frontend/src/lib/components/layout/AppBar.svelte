<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { m } from '$lib/i18n';
	import { notificationCount } from '$lib/stores/notifications';
	import { hasInAppHistory, logicalParent } from './navigation';

	interface Props {
		title?: string;
		showBack?: boolean;
		transparent?: boolean;
	}

	let { title, showBack = false, transparent = false }: Props = $props();

	/** Back within the app; after a deep link (no in-app history) go to the logical parent. */
	function goBack() {
		if (hasInAppHistory()) {
			history.back();
		} else {
			void goto(logicalParent(page.url.pathname));
		}
	}
</script>

<header
	class="fixed top-0 w-full z-50 transition-all duration-500 {transparent
		? 'bg-transparent'
		: 'bg-surface/80 backdrop-blur-xl shadow-[0_12px_32px_rgba(0,0,0,0.06)]'}"
>
	<div class="flex justify-between items-center px-6 py-4 max-w-lg mx-auto w-full">
		{#if showBack}
			<div class="flex items-center gap-3">
				<button
					onclick={goBack}
					class="text-on-surface-variant hover:text-on-surface transition-colors p-1 -ml-1 rounded-full hover:bg-surface-container-high"
					aria-label={m('common.back')}
				>
					<span class="material-symbols-outlined">arrow_back</span>
				</button>
				<h1 class="font-headline text-primary font-black tracking-tighter text-xl">
					{title ?? m('common.appName')}
				</h1>
			</div>
		{:else}
			<div class="flex items-center gap-2.5">
				<div
					class="w-8 h-8 bg-surface-container-lowest rounded-xl shadow-sm flex items-center justify-center p-1.5 transform -rotate-12 hover:rotate-0 transition-transform duration-300"
				>
					<img src="/favicon.svg" alt="" class="w-full h-full object-contain" />
				</div>
				<h1 class="font-headline text-primary font-black tracking-tighter text-xl translate-y-[0.5px]">
					{title ?? m('common.appName')}
				</h1>
			</div>
		{/if}

		<div class="flex items-center gap-3">
			{#if !showBack}
				<a
					href="/search"
					class="text-on-surface-variant hover:text-on-surface transition-transform hover:scale-105 duration-200"
					aria-label={m('common.search')}
				>
					<span class="material-symbols-outlined">search</span>
				</a>
			{/if}
			<a
				href="/notifications"
				class="relative text-on-surface-variant hover:text-on-surface transition-transform hover:scale-105 duration-200"
				aria-label={$notificationCount > 0
					? m('common.notificationsUnread', { count: $notificationCount })
					: m('common.notifications')}
			>
				<span class="material-symbols-outlined">notifications</span>
				{#if $notificationCount > 0}
					<span
						class="absolute -top-1 -right-1 bg-error text-on-error text-[10px] font-bold rounded-full min-w-[16px] h-4 flex items-center justify-center px-1"
					>
						{$notificationCount > 99 ? '99+' : $notificationCount}
					</span>
				{/if}
			</a>
		</div>
	</div>
</header>
