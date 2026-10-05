import { getLocale, m } from '$lib/i18n';
import type { Notification, NotificationType } from '$lib/types';

/** Compact relative time ("5m", "3h", "2d", then a short date) in the active locale. */
export function relativeTime(iso: string, now: Date = new Date()): string {
	const at = new Date(iso);
	const seconds = Math.floor((now.getTime() - at.getTime()) / 1000);
	if (Number.isNaN(seconds)) return '';
	if (seconds < 60) return m('notif.time.justNow');
	if (seconds < 3600) return m('notif.time.minutes', { n: Math.floor(seconds / 60) });
	if (seconds < 86400) return m('notif.time.hours', { n: Math.floor(seconds / 3600) });
	if (seconds < 604800) return m('notif.time.days', { n: Math.floor(seconds / 86400) });
	return at.toLocaleDateString(getLocale(), { month: 'short', day: 'numeric' });
}

/** Name shown for the actor; null for system notifications. */
export function actorName(n: Notification): string | null {
	if (!n.actor) return null;
	if (n.actor.deleted) return m('notif.item.deletedUser');
	return n.actor.displayName || n.actor.username || null;
}

/** Material Symbols icon for notifications without an actor avatar. */
export function typeIcon(type: NotificationType): string {
	if (type.startsWith('EVENT_')) return 'event';
	if (type.startsWith('MATCH_')) return 'groups';
	if (type === 'POST_LIKE') return 'favorite';
	if (type === 'POST_COMMENT' || type === 'COMMENT_MENTION') return 'chat_bubble';
	if (type === 'POST_TAG') return 'sell';
	if (type.startsWith('FRIEND_')) return 'person_add';
	if (type === 'BGG_IMPORT_COMPLETED') return 'library_add';
	return 'menu_book';
}
