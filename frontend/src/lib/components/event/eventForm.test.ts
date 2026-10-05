import { describe, expect, it } from 'vitest';
import type { Event } from '$lib/types';
import {
	clampPlayers,
	combineLocal,
	emptyForm,
	formFromEvent,
	suggestedTitle,
	toCreatePayload,
	toUpdatePayload,
	validateForm,
	type EventFormValues
} from './eventForm';

const now = new Date(2026, 9, 5, 12, 0);

function values(overrides: Partial<EventFormValues> = {}): EventFormValues {
	return { ...emptyForm(now), title: 'Catan Night', ...overrides };
}

function event(overrides: Partial<Event> = {}): Event {
	return {
		id: 'e1',
		host: { id: 'h', username: 'host', displayName: null, avatarUrl: null },
		game: null,
		title: 'Catan Night',
		description: 'Bring snacks',
		location: '12 Main St',
		locationDisplay: null,
		scheduledAt: new Date(2026, 9, 10, 19, 0).toISOString(),
		maxParticipants: 6,
		participantCount: 1,
		visibility: 'FRIENDS',
		status: 'OPEN',
		myRsvp: 'ACCEPTED',
		isHost: true,
		reminderSent: false,
		participants: [],
		createdAt: now.toISOString(),
		...overrides
	};
}

describe('emptyForm', () => {
	it('defaults to tomorrow 7pm, 8 players, friends-only', () => {
		const form = emptyForm(now);
		expect(form).toMatchObject({ date: '2026-10-06', time: '19:00', maxParticipants: 8, visibility: 'FRIENDS' });
	});
});

describe('combineLocal / clampPlayers', () => {
	it('builds a local date and rejects missing or invalid parts', () => {
		expect(combineLocal('2026-10-06', '19:30')?.getTime()).toBe(new Date(2026, 9, 6, 19, 30).getTime());
		expect(combineLocal('', '19:30')).toBeNull();
		expect(combineLocal('2026-10-06', '')).toBeNull();
		expect(combineLocal('nope', '19:30')).toBeNull();
	});

	it('keeps players within 2–50', () => {
		expect(clampPlayers(1)).toBe(2);
		expect(clampPlayers(51)).toBe(50);
		expect(clampPlayers(7.6)).toBe(8);
		expect(clampPlayers(Number.NaN)).toBe(8);
	});
});

describe('validateForm', () => {
	it('requires a 1–100 character title and a date and time', () => {
		expect(validateForm(values(), now)).toBeNull();
		expect(validateForm(values({ title: '   ' }), now)).toBe('event.form.errorTitle');
		expect(validateForm(values({ title: 'x'.repeat(101) }), now)).toBe('event.form.errorTitle');
		expect(validateForm(values({ time: '' }), now)).toBe('event.form.errorDate');
	});

	it('rejects past starts beyond the 5-minute grace unless the time is unchanged', () => {
		expect(validateForm(values({ date: '2026-10-05', time: '11:58' }), now)).toBeNull();
		expect(validateForm(values({ date: '2026-10-05', time: '11:50' }), now)).toBe('event.form.pastDate');
		expect(validateForm(values({ date: '2026-10-05', time: '11:50' }), now, false)).toBeNull();
	});
});

describe('toCreatePayload', () => {
	it('trims, omits empty optionals and keeps the public area only for public events', () => {
		const payload = toCreatePayload(
			values({
				title: '  Catan Night ',
				description: ' ',
				location: ' Cafe ',
				locationDisplay: 'Downtown',
				maxParticipants: 99,
				game: { id: 'g1', title: 'Catan', thumbnailUrl: null },
				invitedUserIds: ['u1', 'u2']
			})
		);
		expect(payload).toEqual({
			title: 'Catan Night',
			scheduledAt: new Date(2026, 9, 6, 19, 0).toISOString(),
			visibility: 'FRIENDS',
			maxParticipants: 50,
			location: 'Cafe',
			gameId: 'g1',
			invitedUserIds: ['u1', 'u2']
		});
		expect(toCreatePayload(values({ visibility: 'PUBLIC', locationDisplay: 'Downtown' })).locationDisplay).toBe(
			'Downtown'
		);
	});

	it('refuses an unvalidated form', () => {
		expect(() => toCreatePayload(values({ date: '' }))).toThrow();
	});
});

describe('toUpdatePayload', () => {
	it('sends nothing when nothing changed', () => {
		const original = event();
		expect(toUpdatePayload(original, formFromEvent(original))).toEqual({});
	});

	it('sends only changed fields and clears text with an empty string', () => {
		const original = event({ game: { id: 'g1', title: 'Catan', thumbnailUrl: null } as Event['game'] });
		const form = formFromEvent(original);
		const payload = toUpdatePayload(original, {
			...form,
			description: '',
			time: '20:00',
			maxParticipants: 10,
			visibility: 'PUBLIC',
			locationDisplay: 'Downtown',
			game: { id: 'g2', title: 'Wingspan', thumbnailUrl: null }
		});
		expect(payload).toEqual({
			description: '',
			scheduledAt: new Date(2026, 9, 10, 20, 0).toISOString(),
			maxParticipants: 10,
			visibility: 'PUBLIC',
			locationDisplay: 'Downtown',
			gameId: 'g2'
		});
	});

	it('never sends a game removal (the API cannot clear it)', () => {
		const original = event({ game: { id: 'g1', title: 'Catan', thumbnailUrl: null } as Event['game'] });
		expect(toUpdatePayload(original, { ...formFromEvent(original), game: null })).toEqual({});
	});
});

describe('suggestedTitle', () => {
	it('suggests "{game} Night" only while the title is empty', () => {
		const game = { id: 'g', title: 'Catan', thumbnailUrl: null };
		expect(suggestedTitle(game, '')).toBe('Catan Night');
		expect(suggestedTitle(game, 'My night')).toBe('My night');
		expect(suggestedTitle(null, '')).toBe('');
	});
});
