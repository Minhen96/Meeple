import { describe, expect, it, vi } from 'vitest';

// client.ts imports SvelteKit runtime modules that do not exist under vitest
vi.mock('$app/environment', () => ({ browser: false }));
vi.mock('$app/navigation', () => ({ goto: vi.fn() }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));

import { ApiRequestError } from '$lib/api/client';
import type { Event } from '$lib/types';
import {
	displayName,
	eventErrorMessage,
	locationText,
	rsvpAction,
	rsvpLabel,
	statusChipClass,
	statusLabel
} from './eventState';

type ActionInput = Pick<Event, 'isHost' | 'status' | 'myRsvp' | 'visibility'>;

const base: ActionInput = { isHost: false, status: 'OPEN', myRsvp: null, visibility: 'PUBLIC' };

describe('rsvpAction (SCREENS 6.4 action bar)', () => {
	it.each<[Partial<ActionInput>, ReturnType<typeof rsvpAction>]>([
		[{ status: 'CANCELLED', isHost: true }, 'cancelled'],
		[{ status: 'COMPLETED', myRsvp: 'ACCEPTED' }, 'completed'],
		[{ isHost: true, myRsvp: 'ACCEPTED' }, 'host'],
		[{ myRsvp: 'ACCEPTED' }, 'going'],
		[{ myRsvp: 'INVITED' }, 'respond'],
		[{ myRsvp: 'INVITED', status: 'FULL' }, 'respond'],
		[{ myRsvp: 'DECLINED' }, 'changeToGoing'],
		[{ myRsvp: 'DECLINED', status: 'FULL' }, 'full'],
		[{ myRsvp: 'KICKED' }, 'kicked'],
		[{}, 'join'],
		[{ status: 'FULL' }, 'full'],
		[{ myRsvp: 'LEFT' }, 'join'],
		[{ visibility: 'FRIENDS' }, 'none'],
		[{ visibility: 'INVITE_ONLY', myRsvp: 'LEFT' }, 'none'],
		[{ visibility: 'FRIENDS', myRsvp: 'INVITED' }, 'respond']
	])('%o → %s', (overrides, expected) => {
		expect(rsvpAction({ ...base, ...overrides })).toBe(expected);
	});
});

describe('labels', () => {
	it('localizes statuses and RSVP states', () => {
		expect(statusLabel('OPEN')).toBe('Open');
		expect(statusLabel('CANCELLED')).toBe('Cancelled');
		expect(rsvpLabel('ACCEPTED')).toBe('Going');
		expect(rsvpLabel('KICKED')).toBe('Removed');
	});

	it('uses design tokens for status chips', () => {
		expect(statusChipClass('OPEN')).toContain('bg-secondary-container');
		expect(statusChipClass('FULL')).toContain('bg-error-container');
		expect(statusChipClass('COMPLETED')).toContain('bg-surface-container-highest');
	});

	it('prefers the full location and falls back to the public area', () => {
		expect(locationText({ location: '12 Main St', locationDisplay: 'Downtown' })).toBe('12 Main St');
		expect(locationText({ location: null, locationDisplay: 'Downtown' })).toBe('Downtown');
		expect(locationText({ location: null, locationDisplay: null })).toBeNull();
	});

	it('falls back to the username', () => {
		expect(displayName({ displayName: 'Ana', username: 'ana' })).toBe('Ana');
		expect(displayName({ displayName: null, username: 'ana' })).toBe('ana');
	});
});

describe('eventErrorMessage', () => {
	it('maps event codes first, then shared codes, then the generic message', () => {
		expect(eventErrorMessage(new ApiRequestError('NOT_INVITED', 'x', 403))).toBe(
			'You need an invite to join this event.'
		);
		expect(eventErrorMessage(new ApiRequestError('EVENT_FULL', 'x', 409))).toBe('This event is full.');
		expect(eventErrorMessage(new ApiRequestError('SOMETHING_NEW', 'x', 500))).toBe(
			'Something went wrong. Please try again.'
		);
		expect(eventErrorMessage(new Error('boom'))).toBe('Something went wrong. Please try again.');
	});
});
