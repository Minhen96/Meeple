<script lang="ts">
	import { notifications, markAllRead } from '$lib/stores/notifications';
	import { timeAgo } from '$lib/utils/date';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
</script>

<svelte:head><title>Notifications — Meeple & Hearth</title></svelte:head>

<div class="flex items-center justify-between mb-6">
	<h2 class="text-2xl font-extrabold font-headline">Notifications</h2>
	{#if $notifications.some(n => !n.isRead)}
		<button
			onclick={markAllRead}
			class="text-sm text-primary font-semibold"
		>Mark all read</button>
	{/if}
</div>

{#if $notifications.length === 0}
	<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl">check_circle</span>
		<p class="font-semibold">You're all caught up!</p>
		<p class="text-sm">Notifications will appear here.</p>
	</div>
{:else}
	<div class="space-y-2">
		{#each $notifications as notification}
			<a
				href={notification.path ?? '#'}
				class="flex items-start gap-3 p-3 rounded-xl transition-colors {notification.isRead ? 'bg-surface' : 'bg-surface-container-low'}"
			>
				<div class="w-1 h-1 rounded-full mt-2 flex-shrink-0 {notification.isRead ? 'bg-transparent' : 'bg-primary'}"></div>
				<div class="flex-1 min-w-0">
					<p class="text-sm font-semibold text-on-surface">{notification.title}</p>
					<p class="text-xs text-on-surface-variant mt-0.5">{notification.body}</p>
				</div>
				<span class="text-xs text-on-surface-variant flex-shrink-0">{timeAgo(notification.createdAt)}</span>
			</a>
		{/each}
	</div>
{/if}
