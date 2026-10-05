import { describe, expect, it } from 'vitest';
import { deviceIcon, relativeTime } from './sessions';

describe('sessions helpers', () => {
	it('picks an icon from the device description', () => {
		expect(deviceIcon('Safari on iOS')).toBe('smartphone');
		expect(deviceIcon('Meeple app')).toBe('smartphone');
		expect(deviceIcon('Chrome on macOS')).toBe('computer');
		expect(deviceIcon(null)).toBe('devices');
	});

	it('formats last activity relative to now', () => {
		const now = Date.parse('2026-10-05T12:00:00Z');
		expect(relativeTime('2026-10-05T09:00:00Z', 'en', now)).toBe('3 hours ago');
		expect(relativeTime('2026-10-04T12:00:00Z', 'en', now)).toBe('yesterday');
		expect(relativeTime('2026-10-05T11:59:40Z', 'en', now)).toBe('now');
		expect(relativeTime('2026-10-05T09:00:00Z', 'zh-CN', now)).toBe('3小时前');
	});
});
