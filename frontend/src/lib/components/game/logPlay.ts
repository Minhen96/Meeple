// Play-log form validation (UI-free, unit-tested). Mirrors the backend limits of
// POST /users/me/games/{gameId}/plays.
import type { LogPlayPayload } from '$lib/types';

export const MAX_NOTES = 1000;
export const MAX_DURATION_MINUTES = 1440;
export const MAX_PLAYERS = 100;

export interface LogPlayForm {
	/** `YYYY-MM-DD` from a date input, or empty for "now". */
	date: string;
	notes: string;
	/** Raw input values; empty means "not given". */
	durationMinutes: string;
	playerCount: string;
}

export type LogPlayError = 'futureDate' | 'invalidDate' | 'duration' | 'players' | 'notes';

/** Today's date as `YYYY-MM-DD` in local time (the max of the date input). */
export function todayInput(now: Date = new Date()): string {
	const y = now.getFullYear();
	const m = String(now.getMonth() + 1).padStart(2, '0');
	const d = String(now.getDate()).padStart(2, '0');
	return `${y}-${m}-${d}`;
}

function parseIntInRange(raw: string, max: number): number | null | 'invalid' {
	const trimmed = raw.trim();
	if (!trimmed) return null;
	if (!/^\d+$/.test(trimmed)) return 'invalid';
	const n = Number(trimmed);
	return n >= 1 && n <= max ? n : 'invalid';
}

/**
 * Builds the request body. A past date is sent as local noon (so the day is right in every
 * time zone); today's date is sent as "now".
 */
export function buildLogPlayPayload(
	form: LogPlayForm,
	now: Date = new Date()
): { payload: LogPlayPayload } | { error: LogPlayError } {
	const payload: LogPlayPayload = {};

	const date = form.date.trim();
	if (date) {
		const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
		if (!match) return { error: 'invalidDate' };
		if (date > todayInput(now)) return { error: 'futureDate' };
		if (date < todayInput(now)) {
			const local = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]), 12);
			if (Number.isNaN(local.getTime())) return { error: 'invalidDate' };
			payload.playedAt = local.toISOString();
		}
	}

	const duration = parseIntInRange(form.durationMinutes, MAX_DURATION_MINUTES);
	if (duration === 'invalid') return { error: 'duration' };
	if (duration !== null) payload.durationMinutes = duration;

	const players = parseIntInRange(form.playerCount, MAX_PLAYERS);
	if (players === 'invalid') return { error: 'players' };
	if (players !== null) payload.playerCount = players;

	const notes = form.notes.trim();
	if (notes.length > MAX_NOTES) return { error: 'notes' };
	if (notes) payload.notes = notes;

	return { payload };
}
