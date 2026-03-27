<script lang="ts">
	import { goto } from '$app/navigation';
	import { notificationCount } from '$lib/stores/notifications';

	interface Props {
		title?: string;
		showBack?: boolean;
		showSearch?: boolean;
		showNotifications?: boolean;
	}

	let {
		title = 'Meeple & Hearth',
		showBack = false,
		showSearch = true,
		showNotifications = true
	}: Props = $props();

	function goBack() {
		history.back();
	}
</script>

<header
	class="fixed top-0 w-full z-50 bg-[#F8F9FA]/80 backdrop-blur-xl shadow-[0_12px_32px_rgba(0,0,0,0.06)]"
>
	<div class="flex justify-between items-center px-6 py-4 max-w-lg mx-auto w-full">
		<!-- Left slot -->
		{#if showBack}
			<button
				onclick={goBack}
				class="text-on-surface-variant hover:text-on-surface transition-colors"
				aria-label="Go back"
			>
				<span class="material-symbols-outlined">arrow_back</span>
			</button>
		{:else if showSearch}
			<button
				onclick={() => goto('/?search=1')}
				class="text-on-surface-variant hover:text-on-surface transition-colors"
				aria-label="Search"
			>
				<span class="material-symbols-outlined">search</span>
			</button>
		{:else}
			<div class="w-6"></div>
		{/if}

		<!-- Title -->
		<h1 class="font-headline text-primary font-black tracking-tighter text-xl">{title}</h1>

		<!-- Right slot -->
		{#if showNotifications}
			<a
				href="/notifications"
				class="relative text-on-surface-variant hover:text-on-surface transition-colors"
				aria-label="Notifications"
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
		{:else}
			<div class="w-6"></div>
		{/if}
	</div>
</header>
