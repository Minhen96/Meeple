import { writable, derived, get } from 'svelte/store';
import type { Notification, NotificationWsPayload } from '$lib/types';

/** Notifications loaded so far (newest first). */
export const notifications = writable<Notification[]>([]);

/**
 * Server-side unread count (REST `/unread-count` and every WebSocket frame). Null until known;
 * the badge then falls back to the unread items loaded in `notifications`.
 */
export const unreadCount = writable<number | null>(null);

/** Bell badge value. */
export const notificationCount = derived(
	[notifications, unreadCount],
	([$notifications, $unread]) => $unread ?? $notifications.filter((n) => !n.read).length
);

export function setUnreadCount(count: number) {
	unreadCount.set(Math.max(0, Math.floor(count)));
}

/** Insert or replace (a batched like updates its existing item), keeping newest first. */
export function addNotification(notification: Notification) {
	notifications.update((list) => [notification, ...list.filter((n) => n.id !== notification.id)]);
}

/** Append an older page, skipping items already present. */
export function appendNotifications(page: Notification[]) {
	notifications.update((list) => {
		const seen = new Set(list.map((n) => n.id));
		return [...list, ...page.filter((n) => !seen.has(n.id))];
	});
}

/** Local state after the server marked one item read. */
export function markRead(id: string) {
	let changed = false;
	notifications.update((list) =>
		list.map((n) => {
			if (n.id !== id || n.read) return n;
			changed = true;
			return { ...n, read: true };
		})
	);
	if (changed) adjustUnread(-1);
}

export function markAllRead() {
	notifications.update((list) => list.map((n) => (n.read ? n : { ...n, read: true })));
	unreadCount.set(0);
}

export function removeNotification(id: string) {
	const target = get(notifications).find((n) => n.id === id);
	notifications.update((list) => list.filter((n) => n.id !== id));
	if (target && !target.read) adjustUnread(-1);
}

function adjustUnread(delta: number) {
	unreadCount.update((count) => (count === null ? null : Math.max(0, count + delta)));
}

/** Apply a `/user/queue/notifications` frame. */
export function applyNotificationFrame(payload: NotificationWsPayload) {
	addNotification(payload.notification);
	setUnreadCount(payload.unreadCount);
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === 'object' && value !== null;
}

function isNotification(value: unknown): value is Notification {
	return (
		isRecord(value) &&
		typeof value.id === 'string' &&
		typeof value.type === 'string' &&
		typeof value.createdAt === 'string' &&
		typeof value.read === 'boolean'
	);
}

/** Fill fields older backends left out so the UI can rely on the NotificationDto shape. */
function normalize(n: Notification): Notification {
	const data =
		isRecord(n.data) && typeof n.data.path === 'string'
			? n.data
			: { ...n.data, path: '/notifications' };
	return {
		...n,
		actor: n.actor ?? null,
		title: n.title ?? '',
		body: n.body ?? null,
		data
	};
}

/**
 * Parse a STOMP frame body: `{notification, unreadCount}`, or a bare notification from an older
 * backend (no count). Returns null for anything malformed.
 */
export function parseNotificationFrame(
	body: string
): { notification: Notification; unreadCount: number | null } | null {
	let value: unknown;
	try {
		value = JSON.parse(body);
	} catch {
		return null;
	}
	if (isRecord(value) && isNotification(value.notification)) {
		const count = typeof value.unreadCount === 'number' ? value.unreadCount : null;
		return { notification: normalize(value.notification), unreadCount: count };
	}
	if (isNotification(value)) return { notification: normalize(value), unreadCount: null };
	return null;
}

/** Handle a raw frame body; returns whether it was a valid notification. */
export function handleNotificationFrame(body: string): boolean {
	const frame = parseNotificationFrame(body);
	if (!frame) return false;
	addNotification(frame.notification);
	if (frame.unreadCount !== null) setUnreadCount(frame.unreadCount);
	else if (!frame.notification.read) adjustUnread(1);
	return true;
}

// ─── Grouping (SCREENS_AND_STATES section 9: Today | This Week | Earlier) ───

export type NotificationGroupKey = 'today' | 'thisWeek' | 'earlier';

export interface NotificationGroup {
	key: NotificationGroupKey;
	items: Notification[];
}

/**
 * Split a newest-first list into Today (since local midnight), This Week (the 6 days before
 * today) and Earlier. Empty groups are omitted; order inside a group is kept.
 */
export function groupNotifications(
	list: Notification[],
	now: Date = new Date()
): NotificationGroup[] {
	const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
	const startOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6).getTime();
	const groups: Record<NotificationGroupKey, Notification[]> = {
		today: [],
		thisWeek: [],
		earlier: []
	};
	for (const n of list) {
		const at = new Date(n.createdAt).getTime();
		if (Number.isNaN(at) || at < startOfWeek) groups.earlier.push(n);
		else if (at < startOfToday) groups.thisWeek.push(n);
		else groups.today.push(n);
	}
	return (['today', 'thisWeek', 'earlier'] as const)
		.filter((key) => groups[key].length > 0)
		.map((key) => ({ key, items: groups[key] }));
}

/** In-app path to open for a notification; never an external URL. */
export function notificationHref(n: Notification): string {
	const path = n.data?.path;
	if (
		typeof path === 'string' &&
		path.startsWith('/') &&
		!path.startsWith('//') &&
		!path.includes('\\')
	) {
		return path;
	}
	return '/notifications';
}

/** Clear everything (logout). */
export function resetNotifications() {
	notifications.set([]);
	unreadCount.set(null);
}
