import { describe, expect, it } from 'vitest';
import type { Event } from '$lib/types';
import { addMonths, dayKey, gridRange, groupByDay, monthGrid, monthOf, weekdayLabels } from './calendar';

function event(id: string, scheduledAt: Date): Event {
	return {
		id,
		host: { id: 'h', username: 'host', displayName: null, avatarUrl: null },
		game: null,
		title: id,
		description: null,
		location: null,
		locationDisplay: null,
		scheduledAt: scheduledAt.toISOString(),
		maxParticipants: 8,
		participantCount: 1,
		visibility: 'FRIENDS',
		status: 'OPEN',
		myRsvp: null,
		isHost: false,
		reminderSent: false,
		participants: [],
		createdAt: scheduledAt.toISOString()
	};
}

describe('monthGrid', () => {
	it('covers whole weeks starting on Sunday around October 2026', () => {
		// 1 Oct 2026 is a Thursday; 31 Oct a Saturday
		const cells = monthGrid({ year: 2026, month: 9 }, new Date(2026, 9, 5));
		expect(cells).toHaveLength(35);
		expect(cells[0].key).toBe('2026-09-27');
		expect(cells[0].inMonth).toBe(false);
		expect(cells[4]).toMatchObject({ key: '2026-10-01', day: 1, inMonth: true });
		expect(cells[34].key).toBe('2026-10-31');
		expect(cells.filter((c) => c.isToday).map((c) => c.key)).toEqual(['2026-10-05']);
		expect(cells.every((c) => c.date.getHours() === 0)).toBe(true);
	});

	it('uses six rows when the month needs them and four for a fitted February', () => {
		// August 2026 starts on a Saturday and has 31 days
		expect(monthGrid({ year: 2026, month: 7 })).toHaveLength(42);
		// February 2026 starts on a Sunday and has 28 days
		const feb = monthGrid({ year: 2026, month: 1 });
		expect(feb).toHaveLength(28);
		expect(feb.every((c) => c.inMonth)).toBe(true);
	});

	it('supports Monday as the first day of the week', () => {
		const cells = monthGrid({ year: 2026, month: 9 }, new Date(2026, 0, 1), 1);
		expect(cells[0].key).toBe('2026-09-28');
		expect(cells[0].date.getDay()).toBe(1);
		expect(cells.length % 7).toBe(0);
	});
});

describe('month navigation', () => {
	it('crosses year boundaries', () => {
		expect(addMonths({ year: 2026, month: 11 }, 1)).toEqual({ year: 2027, month: 0 });
		expect(addMonths({ year: 2026, month: 0 }, -1)).toEqual({ year: 2025, month: 11 });
		expect(addMonths({ year: 2026, month: 5 }, 0)).toEqual({ year: 2026, month: 5 });
		expect(monthOf(new Date(2026, 3, 30))).toEqual({ year: 2026, month: 3 });
	});
});

describe('gridRange', () => {
	it('spans first cell midnight to the day after the last cell, within the 62-day API limit', () => {
		const cells = monthGrid({ year: 2026, month: 7 });
		const { from, to } = gridRange(cells);
		expect(dayKey(from)).toBe(cells[0].key);
		expect(from.getHours()).toBe(0);
		expect(dayKey(to)).toBe('2026-09-06');
		expect((to.getTime() - from.getTime()) / 86_400_000).toBeLessThanOrEqual(62);
	});
});

describe('groupByDay', () => {
	it('groups by local day and sorts each day by start time', () => {
		const late = event('late', new Date(2026, 9, 5, 20, 0));
		const early = event('early', new Date(2026, 9, 5, 9, 30));
		const other = event('other', new Date(2026, 9, 6, 0, 0));
		const byDay = groupByDay([late, other, early]);
		expect(byDay.get('2026-10-05')?.map((e) => e.id)).toEqual(['early', 'late']);
		expect(byDay.get('2026-10-06')?.map((e) => e.id)).toEqual(['other']);
		expect(byDay.has('2026-10-07')).toBe(false);
	});
});

describe('weekdayLabels', () => {
	it('returns seven labels starting at the requested day', () => {
		expect(weekdayLabels('en-US')).toEqual(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
		expect(weekdayLabels('en-US', 1)[0]).toBe('Mon');
	});
});
