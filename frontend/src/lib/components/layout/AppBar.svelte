<script lang="ts">
	import { goto } from '$app/navigation';
	import { notificationCount } from '$lib/stores/notifications';

	interface Props {
		title?: string;
		showBack?: boolean;
	}

	let { title = 'Meeple & Hearth', showBack = false }: Props = $props();

	function goBack() {
		history.back();
	}
</script>

<header
	class="fixed top-0 w-full z-50 bg-[#F8F9FA]/80 backdrop-blur-xl shadow-[0_12px_32px_rgba(0,0,0,0.06)]"
>
	<div class="flex justify-between items-center px-6 py-4 max-w-lg mx-auto w-full">
		<!-- Left: back button on detail pages, title on root pages -->
		{#if showBack}
			<button
				onclick={goBack}
				class="text-on-surface-variant hover:text-on-surface transition-colors"
				aria-label="Go back"
			>
				<span class="material-symbols-outlined">arrow_back</span>
			</button>
			<h1 class="font-headline text-primary font-black tracking-tighter text-xl">{title}</h1>
		{:else}
			<h1 class="font-headline text-primary font-black tracking-tighter text-xl">{title}</h1>
		{/if}

		<!-- Right: search + notifications -->
		<div class="flex items-center gap-3">
			{#if !showBack}
				<button
					onclick={() => goto('/library?search=1')}
					class="text-on-surface-variant hover:text-on-surface transition-transform hover:scale-105 duration-200"
					aria-label="Search"
				>
					<span class="material-symbols-outlined">search</span>
				</button>
			{/if}
			<a
				href="/notifications"
				class="relative text-on-surface-variant hover:text-on-surface transition-transform hover:scale-105 duration-200"
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
		</div>
	</div>
</header>
