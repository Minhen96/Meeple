/** Icon for a session's device description ("Chrome on macOS", "Meeple app", "Safari on iOS"). */
export function deviceIcon(deviceInfo: string | null): string {
	const info = (deviceInfo ?? '').toLowerCase();
	if (info.includes('ios') || info.includes('android') || info.includes('app')) return 'smartphone';
	if (info.includes('windows') || info.includes('macos') || info.includes('linux') || info.includes('chromeos')) {
		return 'computer';
	}
	return 'devices';
}

const UNITS: [Intl.RelativeTimeFormatUnit, number][] = [
	['year', 365 * 24 * 3600],
	['month', 30 * 24 * 3600],
	['week', 7 * 24 * 3600],
	['day', 24 * 3600],
	['hour', 3600],
	['minute', 60]
];

/** "3 hours ago" / "3 小时前" for an ISO time, relative to `now`. Under a minute: "now". */
export function relativeTime(iso: string, locale: string, now: number = Date.now()): string {
	const seconds = Math.round((new Date(iso).getTime() - now) / 1000);
	const format = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
	for (const [unit, size] of UNITS) {
		if (Math.abs(seconds) >= size) return format.format(Math.round(seconds / size), unit);
	}
	return format.format(0, 'second');
}
