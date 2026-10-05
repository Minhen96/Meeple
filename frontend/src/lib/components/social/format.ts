import { getLocale, m } from '$lib/i18n';

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/** "Just now" / "5m ago" / "3h ago" / "2d ago" / a short date after a week. */
export function timeAgo(iso: string, now: Date = new Date()): string {
	const then = new Date(iso);
	const diff = now.getTime() - then.getTime();
	if (diff < MINUTE) return m('social.time.justNow');
	if (diff < HOUR) return m('social.time.minutesAgo', { count: Math.floor(diff / MINUTE) });
	if (diff < DAY) return m('social.time.hoursAgo', { count: Math.floor(diff / HOUR) });
	if (diff < 7 * DAY) return m('social.time.daysAgo', { count: Math.floor(diff / DAY) });
	return then.toLocaleDateString(getLocale(), {
		month: 'short',
		day: 'numeric'
	});
}

/** Whole calendar days from `now` until `iso` in local time (0 = today); null if in the past. */
export function daysUntil(iso: string, now: Date = new Date()): number | null {
	const target = new Date(iso);
	if (target.getTime() < now.getTime()) return null;
	const startOf = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
	return Math.round((startOf(target) - startOf(now)) / DAY);
}

/** The greeting key for the hour: morning 6–12, afternoon 12–18, evening otherwise (SCREENS 4.3). */
export function greetingKey(
	hour: number
): 'social.home.morning' | 'social.home.afternoon' | 'social.home.evening' {
	if (hour >= 6 && hour < 12) return 'social.home.morning';
	if (hour >= 12 && hour < 18) return 'social.home.afternoon';
	return 'social.home.evening';
}

/** Display name for a user reference; soft-deleted accounts render as "Deleted User". */
export function displayName(user: {
	username: string;
	displayName: string | null;
	deleted?: boolean;
}): string {
	if (user.deleted) return m('social.deletedUser');
	return user.displayName || user.username;
}

/**
 * Splits a message template around one `{slot}` so a component can render a styled element there:
 * `splitTemplate('{name} added {game} here', 'game')` → `['{name} added ', ' here']`.
 */
export function splitTemplate(template: string, slot: string): [string, string] {
	const marker = `{${slot}}`;
	const at = template.indexOf(marker);
	if (at < 0) return [template, ''];
	return [template.slice(0, at), template.slice(at + marker.length)];
}
