// Event view logic shared by the event screens: RSVP action (SCREENS section 6.4), labels, errors.
import { ApiRequestError } from '$lib/api/client';
import { errorMessage, m, type MessageKey } from '$lib/i18n';
import type { Event, EventStatus, RsvpStatus } from '$lib/types';

/** What the action bar shows for the viewer (SCREENS section 6.4 "RSVP action bar states"). */
export type RsvpAction =
	| 'host' // "Manage Event" dropdown
	| 'cancelled' // banner only, no actions
	| 'completed' // banner + "View Memories"
	| 'respond' // invited: Accept + Decline
	| 'going' // accepted: Leave Event
	| 'changeToGoing' // declined: Change to Going
	| 'join' // public event, not part of it yet
	| 'full' // "Event is Full" (disabled)
	| 'kicked' // removed by the host
	| 'none'; // private event, not invited (or left one)

export function rsvpAction(event: Pick<Event, 'isHost' | 'status' | 'myRsvp' | 'visibility'>): RsvpAction {
	if (event.status === 'CANCELLED') return 'cancelled';
	if (event.status === 'COMPLETED') return 'completed';
	if (event.isHost) return 'host';
	switch (event.myRsvp) {
		case 'ACCEPTED':
			return 'going';
		case 'KICKED':
			return 'kicked';
		case 'INVITED':
			// Declining stays possible on a full event; the UI disables Accept
			return 'respond';
		case 'DECLINED':
			return event.status === 'FULL' ? 'full' : 'changeToGoing';
		default:
			// No row or LEFT: only PUBLIC events are open-join (decision C9)
			if (event.visibility !== 'PUBLIC') return 'none';
			return event.status === 'FULL' ? 'full' : 'join';
	}
}

const STATUS_KEYS: Record<EventStatus, MessageKey> = {
	OPEN: 'event.status.open',
	FULL: 'event.status.full',
	COMPLETED: 'event.status.completed',
	CANCELLED: 'event.status.cancelled'
};

export function statusLabel(status: EventStatus): string {
	return m(STATUS_KEYS[status]);
}

const RSVP_KEYS: Record<RsvpStatus, MessageKey> = {
	INVITED: 'event.rsvp.invited',
	ACCEPTED: 'event.rsvp.accepted',
	DECLINED: 'event.rsvp.declined',
	LEFT: 'event.rsvp.left',
	KICKED: 'event.rsvp.kicked'
};

export function rsvpLabel(status: RsvpStatus): string {
	return m(RSVP_KEYS[status]);
}

/** Tailwind classes for the status chip (DESIGN section 9 "Status Chip"). */
export function statusChipClass(status: EventStatus): string {
	switch (status) {
		case 'OPEN':
			return 'bg-secondary-container text-on-secondary-container';
		case 'FULL':
			return 'bg-error-container text-on-error-container';
		default:
			return 'bg-surface-container-highest text-on-surface-variant';
	}
}

/** Where the event is, as the viewer may see it. */
export function locationText(event: Pick<Event, 'location' | 'locationDisplay'>): string | null {
	return event.location ?? event.locationDisplay;
}

/** Event-specific backend codes (not in the shared errors namespace). */
const EVENT_ERROR_KEYS: Readonly<Record<string, MessageKey>> = {
	NOT_INVITED: 'event.error.notInvited',
	KICKED: 'event.error.kicked',
	MAX_BELOW_ACCEPTED: 'event.error.maxBelowAccepted',
	HOST_CANNOT_LEAVE: 'event.error.hostCannotLeave',
	CANNOT_INVITE_SELF: 'event.error.cannotInviteSelf',
	INVALID_STATUS_TRANSITION: 'event.error.invalidTransition',
	NOT_PARTICIPANT: 'event.error.notParticipant',
	INVALID_RANGE: 'event.error.generic',
	INVALID_TIME: 'event.error.pastDate'
};

/** Localized message for a failed event request. */
export function eventErrorMessage(err: unknown): string {
	if (err instanceof ApiRequestError) {
		const key = EVENT_ERROR_KEYS[err.code];
		return key ? m(key) : errorMessage(err.code);
	}
	return errorMessage(null);
}

export function formatEventDateTime(iso: string, locale: string): string {
	return new Date(iso).toLocaleString(locale, {
		weekday: 'long',
		month: 'long',
		day: 'numeric',
		hour: 'numeric',
		minute: '2-digit'
	});
}

export function formatEventTime(iso: string, locale: string): string {
	return new Date(iso).toLocaleTimeString(locale, { hour: 'numeric', minute: '2-digit' });
}

export function displayName(user: { displayName: string | null; username: string }): string {
	return user.displayName ?? user.username;
}
