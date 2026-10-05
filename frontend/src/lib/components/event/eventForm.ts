// Create / edit event form logic (SCREENS section 6.5; limits per FEATURES section 12.1).
import type { CreateEventPayload, UpdateEventPayload } from '$lib/api/events';
import type { MessageKey } from '$lib/i18n';
import type { Event, EventVisibility } from '$lib/types';

export const TITLE_MAX = 100;
export const LOCATION_MAX = 100;
export const DESCRIPTION_MAX = 1000;
export const MIN_PLAYERS = 2;
export const MAX_PLAYERS = 50;
export const DEFAULT_PLAYERS = 8;
/** The backend accepts start times up to 5 minutes in the past (clock drift). */
export const PAST_GRACE_MS = 5 * 60 * 1000;

export interface PickedGame {
	id: string;
	title: string;
	thumbnailUrl: string | null;
}

export interface EventFormValues {
	title: string;
	description: string;
	location: string;
	locationDisplay: string;
	/** `YYYY-MM-DD` (local) */
	date: string;
	/** `HH:mm` (local) */
	time: string;
	maxParticipants: number;
	visibility: EventVisibility;
	game: PickedGame | null;
	invitedUserIds: string[];
}

function pad(n: number): string {
	return n < 10 ? `0${n}` : String(n);
}

export function toDateInput(d: Date): string {
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function toTimeInput(d: Date): string {
	return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** Local date + time inputs as a Date, or null if either is missing or invalid. */
export function combineLocal(date: string, time: string): Date | null {
	if (!date || !time) return null;
	const [y, mo, d] = date.split('-').map(Number);
	const [h, mi] = time.split(':').map(Number);
	if ([y, mo, d, h, mi].some((n) => Number.isNaN(n))) return null;
	const result = new Date(y, mo - 1, d, h, mi);
	return Number.isNaN(result.getTime()) ? null : result;
}

export function clampPlayers(n: number): number {
	if (!Number.isFinite(n)) return DEFAULT_PLAYERS;
	return Math.min(MAX_PLAYERS, Math.max(MIN_PLAYERS, Math.round(n)));
}

/** Default values for a new event: next full hour + 1 day, 8 players, friends-only. */
export function emptyForm(now: Date = new Date()): EventFormValues {
	const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 19, 0);
	return {
		title: '',
		description: '',
		location: '',
		locationDisplay: '',
		date: toDateInput(start),
		time: toTimeInput(start),
		maxParticipants: DEFAULT_PLAYERS,
		visibility: 'FRIENDS',
		game: null,
		invitedUserIds: []
	};
}

export function formFromEvent(event: Event): EventFormValues {
	const start = new Date(event.scheduledAt);
	return {
		title: event.title,
		description: event.description ?? '',
		location: event.location ?? '',
		locationDisplay: event.locationDisplay ?? '',
		date: toDateInput(start),
		time: toTimeInput(start),
		maxParticipants: event.maxParticipants,
		visibility: event.visibility,
		game: event.game ? { id: event.game.id, title: event.game.title, thumbnailUrl: event.game.thumbnailUrl } : null,
		invitedUserIds: []
	};
}

/**
 * First problem with the form, as a message key, or null when it can be submitted.
 * `checkPast` is false when editing an event whose time is unchanged.
 */
export function validateForm(values: EventFormValues, now: Date = new Date(), checkPast = true): MessageKey | null {
	const title = values.title.trim();
	if (!title || title.length > TITLE_MAX) return 'event.form.errorTitle';
	const start = combineLocal(values.date, values.time);
	if (!start) return 'event.form.errorDate';
	if (checkPast && start.getTime() < now.getTime() - PAST_GRACE_MS) return 'event.form.pastDate';
	return null;
}

export function toCreatePayload(values: EventFormValues): CreateEventPayload {
	const start = combineLocal(values.date, values.time);
	if (!start) throw new Error('validateForm must pass before building the payload');
	const payload: CreateEventPayload = {
		title: values.title.trim(),
		scheduledAt: start.toISOString(),
		visibility: values.visibility,
		maxParticipants: clampPlayers(values.maxParticipants)
	};
	const description = values.description.trim();
	const location = values.location.trim();
	const locationDisplay = values.locationDisplay.trim();
	if (description) payload.description = description;
	if (location) payload.location = location;
	if (locationDisplay && values.visibility === 'PUBLIC') payload.locationDisplay = locationDisplay;
	if (values.game) payload.gameId = values.game.id;
	if (values.invitedUserIds.length > 0) payload.invitedUserIds = [...values.invitedUserIds];
	return payload;
}

/** Only the fields that changed; cleared text is sent as '' (the backend clears it). */
export function toUpdatePayload(original: Event, values: EventFormValues): UpdateEventPayload {
	const payload: UpdateEventPayload = {};
	const before = formFromEvent(original);

	const title = values.title.trim();
	if (title !== original.title) payload.title = title;
	const description = values.description.trim();
	if (description !== before.description) payload.description = description;
	const location = values.location.trim();
	// A masked location (null for viewers who have not joined) is never edited by its host,
	// so comparing against the loaded value is safe.
	if (location !== before.location) payload.location = location;
	const locationDisplay = values.locationDisplay.trim();
	if (locationDisplay !== before.locationDisplay) payload.locationDisplay = locationDisplay;

	const start = combineLocal(values.date, values.time);
	if (start && (values.date !== before.date || values.time !== before.time)) {
		payload.scheduledAt = start.toISOString();
	}
	const players = clampPlayers(values.maxParticipants);
	if (players !== original.maxParticipants) payload.maxParticipants = players;
	if (values.visibility !== original.visibility) payload.visibility = values.visibility;
	if (values.game && values.game.id !== original.game?.id) payload.gameId = values.game.id;
	return payload;
}

/** "{Game} Night" title suggestion when a game is picked and the title is still empty. */
export function suggestedTitle(game: PickedGame | null, currentTitle: string): string {
	if (!game || currentTitle.trim()) return currentTitle;
	return `${game.title} Night`.slice(0, TITLE_MAX);
}
