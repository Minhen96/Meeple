import { writable, derived } from 'svelte/store';
import type { Notification } from '$lib/types';

export const notifications = writable<Notification[]>([]);

export const notificationCount = derived(
	notifications,
	($notifications) => $notifications.filter((n) => !n.read).length
);

export function addNotification(notification: Notification) {
	notifications.update((list) => [notification, ...list]);
}

export function markRead(id: string) {
	notifications.update((list) =>
		list.map((n) => (n.id === id ? { ...n, read: true } : n))
	);
}

export function markAllRead() {
	notifications.update((list) => list.map((n) => ({ ...n, read: true })));
}
