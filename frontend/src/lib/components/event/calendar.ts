// Monthly calendar grid (SCREENS section 6.3): pure date maths, in the viewer's local time zone.
import type { Event } from '$lib/types';

export interface CalendarCell {
	/** Local midnight of this day. */
	date: Date;
	/** `YYYY-MM-DD` in local time; matches `dayKey()` of events on this day. */
	key: string;
	day: number;
	inMonth: boolean;
	isToday: boolean;
}

export interface MonthRef {
	year: number;
	/** 0-based like `Date#getMonth()`. */
	month: number;
}

function pad(n: number): string {
	return n < 10 ? `0${n}` : String(n);
}

/** Local calendar day of a date or ISO instant, as `YYYY-MM-DD`. */
export function dayKey(value: Date | string): string {
	const d = typeof value === 'string' ? new Date(value) : value;
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** The month containing `date`. */
export function monthOf(date: Date): MonthRef {
	return { year: date.getFullYear(), month: date.getMonth() };
}

/** `ref` moved by `delta` months (handles year boundaries). */
export function addMonths(ref: MonthRef, delta: number): MonthRef {
	const d = new Date(ref.year, ref.month + delta, 1);
	return { year: d.getFullYear(), month: d.getMonth() };
}

/**
 * Whole weeks covering the month: starts on the `weekStartsOn` day (0 = Sunday) on or before
 * the 1st and ends on the day before the next week start after the last day. 4–6 rows of 7.
 */
export function monthGrid(ref: MonthRef, today: Date = new Date(), weekStartsOn = 0): CalendarCell[] {
	const first = new Date(ref.year, ref.month, 1);
	const lead = (first.getDay() - weekStartsOn + 7) % 7;
	const daysInMonth = new Date(ref.year, ref.month + 1, 0).getDate();
	const total = Math.ceil((lead + daysInMonth) / 7) * 7;
	const todayKey = dayKey(today);

	const cells: CalendarCell[] = [];
	for (let i = 0; i < total; i++) {
		// Constructing from y/m/d (not adding ms) keeps local midnight across DST changes.
		const date = new Date(ref.year, ref.month, 1 - lead + i);
		const key = dayKey(date);
		cells.push({
			date,
			key,
			day: date.getDate(),
			inMonth: date.getMonth() === ref.month,
			isToday: key === todayKey
		});
	}
	return cells;
}

/** `[from, to)` instants covering every cell, for `GET /events/calendar` (at most 42 days). */
export function gridRange(cells: CalendarCell[]): { from: Date; to: Date } {
	const first = cells[0].date;
	const last = cells[cells.length - 1].date;
	return {
		from: new Date(first.getFullYear(), first.getMonth(), first.getDate()),
		to: new Date(last.getFullYear(), last.getMonth(), last.getDate() + 1)
	};
}

/** Events grouped by local day, each day sorted by start time. */
export function groupByDay(events: readonly Event[]): Map<string, Event[]> {
	const byDay = new Map<string, Event[]>();
	for (const event of events) {
		const key = dayKey(event.scheduledAt);
		const list = byDay.get(key);
		if (list) list.push(event);
		else byDay.set(key, [event]);
	}
	for (const list of byDay.values()) {
		list.sort((a, b) => Date.parse(a.scheduledAt) - Date.parse(b.scheduledAt));
	}
	return byDay;
}

/** Seven weekday labels starting at `weekStartsOn`, e.g. ['Sun', 'Mon', …] in the given locale. */
export function weekdayLabels(locale: string, weekStartsOn = 0): string[] {
	// 2023-01-01 was a Sunday.
	return Array.from({ length: 7 }, (_, i) =>
		new Date(2023, 0, 1 + ((weekStartsOn + i) % 7)).toLocaleDateString(locale, { weekday: 'short' })
	);
}
