/**
 * Returns "Good morning", "Good afternoon", or "Good evening"
 * based on the current hour.
 */
export function getGreeting(): string {
	const hour = new Date().getHours();
	if (hour >= 6 && hour < 12) return 'Good morning';
	if (hour >= 12 && hour < 18) return 'Good afternoon';
	return 'Good evening';
}

/**
 * Formats a date string as a relative time label.
 * e.g. "2 hours ago", "3 days ago", "Jan 5"
 */
export function timeAgo(dateStr: string): string {
	const date = new Date(dateStr);
	const now = new Date();
	const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

	if (seconds < 60) return 'just now';
	if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
	if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
	if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;

	return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

/**
 * Formats a scheduled event date.
 * e.g. "Saturday, April 5 · 7:00 PM"
 */
export function formatEventDate(dateStr: string): string {
	const date = new Date(dateStr);
	return date.toLocaleDateString('en-US', {
		weekday: 'long',
		month: 'long',
		day: 'numeric',
		hour: 'numeric',
		minute: '2-digit',
		hour12: true
	});
}

/**
 * Returns number of days until a future date.
 * Returns null if the date is in the past.
 */
export function daysUntil(dateStr: string): number | null {
	const date = new Date(dateStr);
	const now = new Date();
	const diff = Math.ceil((date.getTime() - now.getTime()) / 86400000);
	return diff > 0 ? diff : null;
}
