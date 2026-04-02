<script lang="ts">
	import { onMount } from 'svelte';
	import { notifications, markAllRead, notificationCount } from '$lib/stores/notifications';
	import { notificationsApi } from '$lib/api/notifications';
	import { timeAgo } from '$lib/utils/date';

	let loading = $state(true);

	onMount(async () => {
		try {
			const res = await notificationsApi.getAll();
			notifications.set(res ?? []);
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
			case 'FRIEND_REQUEST':  return 'sent you a friend request';
			case 'FRIEND_ACCEPTED': return 'accepted your friend request';
			case 'POST_LIKE':       return 'liked your post';
			case 'POST_COMMENT':    return 'commented on your post';
			case 'EVENT_INVITE':    return 'invited you to an event';
			case 'EVENT_RSVP':      return 'joined your event';
			case 'MATCH_FOUND':     return 'A match was found for you!';
			default:                return 'sent you a notification';
		}
	}

	function notifIcon(type: string): string {
		switch (type) {
			case 'FRIEND_REQUEST':
			case 'FRIEND_ACCEPTED': return 'person_add';
			case 'POST_LIKE':       return 'favorite';
			case 'POST_COMMENT':    return 'chat_bubble';
			case 'EVENT_INVITE':
			case 'EVENT_RSVP':      return 'event';
			case 'MATCH_FOUND':     return 'groups';
			default:                return 'notifications';
		}
	}

	function notifBorderColor(type: string): string {
		switch (type) {
			case 'FRIEND_REQUEST':
			case 'FRIEND_ACCEPTED': return 'border-l-primary';
			case 'POST_LIKE':       return 'border-l-error';
			case 'POST_COMMENT':    return 'border-l-secondary';
			case 'EVENT_INVITE':
			case 'EVENT_RSVP':      return 'border-l-primary-container';
			case 'MATCH_FOUND':     return 'border-l-tertiary';
			default:                return 'border-l-outline-variant';
		}
	}

	function notifIconColor(type: string): string {
		switch (type) {
			case 'FRIEND_REQUEST':
			case 'FRIEND_ACCEPTED': return 'text-primary';
			case 'POST_LIKE':       return 'text-error';
			case 'POST_COMMENT':    return 'text-secondary';
			case 'EVENT_INVITE':
			case 'EVENT_RSVP':      return 'text-primary-container';
			case 'MATCH_FOUND':     return 'text-tertiary';
			default:                return 'text-on-surface-variant';
		}
	}

	function notifHref(n: { type: string; referenceId: string | null; actorId: string | null }): string {
		switch (n.type) {
			case 'FRIEND_REQUEST':
			case 'FRIEND_ACCEPTED': return n.actorId ? `/profile/${n.actorId}` : '#';
			case 'POST_LIKE':
			case 'POST_COMMENT':    return n.referenceId ? `/posts/${n.referenceId}` : '#';
			case 'EVENT_INVITE':
			case 'EVENT_RSVP':      return n.referenceId ? `/events/${n.referenceId}` : '#';
			default:                return '#';
		}
	}
</script>

<svelte:head><title>Notifications — Meeple</title></svelte:head>

<div class="flex items-center justify-between mb-6">
	<h2 class="text-2xl font-extrabold font-headline">Notifications</h2>
	{#if $notificationCount > 0}
		<button onclick={handleMarkAllRead} class="text-sm text-primary font-label font-semibold">
			Mark all read
		</button>
	{/if}
</div>

{#if loading}
	<div class="space-y-3">
		{#each Array(5) as _}
			<div class="h-16 bg-surface-container-low rounded-xl animate-pulse"></div>
		{/each}
	</div>
{:else if $notifications.length === 0}
	<div class="flex flex-col items-center gap-3 py-20 text-center text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl opacity-40" style="font-variation-settings: 'FILL' 1;">check_circle</span>
		<p class="font-semibold">You're all caught up!</p>
		<p class="text-sm">Notifications will appear here.</p>
	</div>
{:else}
	<div class="space-y-2">
		{#each $notifications as notification (notification.id)}
			<a
				href={notifHref(notification)}
				class="flex items-start gap-3 p-4 rounded-xl border-l-4 transition-colors
					{notification.read ? 'bg-surface' : 'bg-surface-container-low'}
					{notifBorderColor(notification.type)}"
			>
				<!-- Icon -->
				<div class="flex-shrink-0 w-9 h-9 rounded-full bg-surface-container flex items-center justify-center">
					<span
						class="material-symbols-outlined text-[18px] {notifIconColor(notification.type)}"
						style={notification.type === 'POST_LIKE' ? "font-variation-settings: 'FILL' 1;" : ''}
					>
						{notifIcon(notification.type)}
					</span>
				</div>

				<!-- Content -->
				<div class="flex-1 min-w-0">
					<p class="text-sm text-on-surface leading-snug">{notifLabel(notification.type)}</p>
					<p class="text-xs text-on-surface-variant mt-0.5">{timeAgo(notification.createdAt)}</p>
				</div>

				<!-- Unread dot -->
				{#if !notification.read}
					<div class="w-2 h-2 rounded-full bg-primary flex-shrink-0 mt-1.5"></div>
				{/if}
			</a>
		{/each}
	</div>
{/if}
