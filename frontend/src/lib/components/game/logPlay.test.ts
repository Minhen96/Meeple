import { describe, expect, it } from 'vitest';
import { buildLogPlayPayload, todayInput, type LogPlayForm } from './logPlay';

const now = new Date(2026, 9, 5, 15, 30); // 5 Oct 2026, local time

function form(overrides: Partial<LogPlayForm> = {}): LogPlayForm {
	return { date: '', notes: '', durationMinutes: '', playerCount: '', ...overrides };
}

describe('todayInput', () => {
	it('formats the local date for a date input', () => {
		expect(todayInput(now)).toBe('2026-10-05');
		expect(todayInput(new Date(2026, 0, 9))).toBe('2026-01-09');
	});
});

describe('buildLogPlayPayload', () => {
	it('sends nothing for an empty form or today (server uses now)', () => {
		expect(buildLogPlayPayload(form(), now)).toEqual({ payload: {} });
		expect(buildLogPlayPayload(form({ date: '2026-10-05' }), now)).toEqual({ payload: {} });
	});

	it('sends a past date as local noon, with trimmed details', () => {
		const result = buildLogPlayPayload(
			form({ date: '2026-10-01', notes: '  Close one ', durationMinutes: '90', playerCount: ' 4 ' }),
			now
		);
		expect(result).toEqual({
			payload: {
				playedAt: new Date(2026, 9, 1, 12).toISOString(),
				notes: 'Close one',
				durationMinutes: 90,
				playerCount: 4
			}
		});
	});

	it('rejects future and malformed dates', () => {
		expect(buildLogPlayPayload(form({ date: '2026-10-06' }), now)).toEqual({ error: 'futureDate' });
		expect(buildLogPlayPayload(form({ date: '05/10/2026' }), now)).toEqual({ error: 'invalidDate' });
	});

	it('rejects out-of-range or non-integer numbers and long notes', () => {
		expect(buildLogPlayPayload(form({ durationMinutes: '0' }), now)).toEqual({ error: 'duration' });
		expect(buildLogPlayPayload(form({ durationMinutes: '1441' }), now)).toEqual({ error: 'duration' });
		expect(buildLogPlayPayload(form({ durationMinutes: '1.5' }), now)).toEqual({ error: 'duration' });
		expect(buildLogPlayPayload(form({ playerCount: '101' }), now)).toEqual({ error: 'players' });
		expect(buildLogPlayPayload(form({ playerCount: '-2' }), now)).toEqual({ error: 'players' });
		expect(buildLogPlayPayload(form({ notes: 'x'.repeat(1001) }), now)).toEqual({ error: 'notes' });
	});
});
