import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { daysUntil, formatEventDate, getGreeting, timeAgo } from './date';

const NOW = new Date(2026, 3, 15, 10, 0, 0); // local time

beforeEach(() => {
	vi.useFakeTimers();
	vi.setSystemTime(NOW);
});

afterEach(() => {
	vi.useRealTimers();
});

const ago = (ms: number) => new Date(NOW.getTime() - ms).toISOString();

describe('getGreeting', () => {
	it.each([
		[5, 'Good evening'],
		[6, 'Good morning'],
		[11, 'Good morning'],
		[12, 'Good afternoon'],
		[17, 'Good afternoon'],
		[18, 'Good evening'],
		[23, 'Good evening']
	])('hour %i -> %s', (hour, expected) => {
		vi.setSystemTime(new Date(2026, 3, 15, hour, 30));
		expect(getGreeting()).toBe(expected);
	});
});

describe('timeAgo', () => {
	it.each([
		[30 * 1000, 'just now'],
		[5 * 60 * 1000, '5m ago'],
		[3 * 3600 * 1000, '3h ago'],
		[2 * 86400 * 1000, '2d ago']
	])('%i ms ago -> %s', (ms, expected) => {
		expect(timeAgo(ago(ms))).toBe(expected);
	});

	it('falls back to a short date after a week', () => {
		expect(timeAgo(new Date(2026, 0, 5, 12).toISOString())).toBe('Jan 5');
	});
});

describe('formatEventDate', () => {
	it('formats weekday, month, day and 12h time', () => {
		const s = formatEventDate(new Date(2026, 3, 18, 19, 0).toISOString());
		expect(s).toContain('Saturday');
		expect(s).toContain('April 18');
		expect(s).toMatch(/7:00\s?PM/);
	});
});

describe('daysUntil', () => {
	it('counts whole days up for future dates and null for past/now', () => {
		expect(daysUntil(new Date(NOW.getTime() + 36 * 3600 * 1000).toISOString())).toBe(2);
		expect(daysUntil(new Date(NOW.getTime() + 1000).toISOString())).toBe(1);
		expect(daysUntil(NOW.toISOString())).toBeNull();
		expect(daysUntil(ago(86400 * 1000))).toBeNull();
	});
});
