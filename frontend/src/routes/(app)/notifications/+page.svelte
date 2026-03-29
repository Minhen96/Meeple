<script lang="ts">
	import { onMount } from 'svelte';
	import { notifications, markAllRead, notificationCount } from '$lib/stores/notifications';
	import { notificationsApi } from '$lib/api/notifications';
	import { timeAgo } from '$lib/utils/date';

	let loading = $state(true);

	onMount(async () => {
		try {
			const res = await notificationsApi.getAll();
			notifications.set(res.data);
		} finally {
			loading = false;
		}
	});

	async function handleMarkAllRead() {
		await notificationsApi.markAllRead();
		markAllRead();
	}

	function notifLabel(type: string): string {
		switch (type) {
			case 'FRIEND_REQUEST': return 'sent you a friend request';
			case 'FRIEND_ACCEPTED': return 'accepted your friend request';
			case 'POST_LIKE': return 'liked your post';
			case 'POST_COMMENT': return 'commented on your post';
			case 'EVENT_INVITE': return 'invited you to an event';
			case 'EVENT_RSVP': return 'joined your event';
			case 'MATCH_FOUND': return 'A match was found for you!';
			default: return 'sent you a notification';
		}
	}

	function notifHref(n: { type: string; referenceId: string | null; actorId: string | null }): string {
		switch (n.type) {
			case 'FRIEND_REQUEST':
			case 'FRIEND_ACCEPTED': return n.actorId ? `/profile/${n.actorId}` : '#';
			case 'POST_LIKE':
			case 'POST_COMMENT': return n.referenceId ? `/posts/${n.referenceId}` : '#';
			case 'EVENT_INVITE':
			case 'EVENT_RSVP': return n.referenceId ? `/events/${n.referenceId}` : '#';
			default: return '#';
		}
	}
</script>

<svelte:head><title>Notifications — Meeple & Hearth</title></svelte:head>

<div class="flex items-center justify-between mb-6">
	<h2 class="text-2xl font-extrabold font-headline">Notifications</h2>
	{#if $notificationCount > 0}
		<button onclick={handleMarkAllRead} class="text-sm text-primary font-semibold">
			Mark all read
		</button>
	{/if}
</div>

{#if loading}
	<div class="space-y-2">
		{#each Array(5) as _}
			<div class="h-14 bg-surface-container-low rounded-xl animate-pulse"></div>
		{/each}
	</div>
{:else if $notifications.length === 0}
	<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl">check_circle</span>
		<p class="font-semibold">You're all caught up!</p>
		<p class="text-sm">Notifications will appear here.</p>
	</div>
{:else}
	<div class="space-y-2">
		{#each $notifications as notification}
			<a
				href={notifHref(notification)}
				class="flex items-start gap-3 p-3 rounded-xl transition-colors {notification.read ? 'bg-surface' : 'bg-surface-container-low'}"
			>
				<div class="w-1.5 h-1.5 rounded-full mt-2 flex-shrink-0 {notification.read ? 'bg-transparent' : 'bg-primary'}"></div>
				<div class="flex-1 min-w-0">
					<p class="text-sm text-on-surface">{notifLabel(notification.type)}</p>
					<p class="text-xs text-on-surface-variant mt-0.5">{timeAgo(notification.createdAt)}</p>
				</div>
			</a>
		{/each}
	</div>
{/if}
