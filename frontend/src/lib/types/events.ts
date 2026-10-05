// Owned by WP2 (events, matching). Re-exported from ./index.ts; import from '$lib/types'.

import type { User } from './account';
import type { GameSummary } from './library';

// ─── Event ─────────────────────────────────────────────────────────────────
// Maps to EventResponse — backend returns uppercase enum names

export type EventVisibility = 'PUBLIC' | 'FRIENDS' | 'INVITE_ONLY';
export type EventStatus = 'OPEN' | 'FULL' | 'COMPLETED' | 'CANCELLED';
export type RsvpStatus = 'INVITED' | 'ACCEPTED' | 'DECLINED' | 'LEFT' | 'KICKED';

/** A participant row: the host sees every status, everyone else only ACCEPTED rows. */
export interface EventParticipant {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	status: RsvpStatus;
}

export interface Event {
	id: string;
	host: {
		id: string;
		/** Null when the host's account was deleted. */
		username: string | null;
		displayName: string | null;
		avatarUrl: string | null;
		deleted?: boolean;
	};
	game: GameSummary | null;
	title: string;
	description: string | null;
	/** Null on a PUBLIC event the viewer has not joined: show `locationDisplay` instead. */
	location: string | null;
	locationDisplay: string | null;
	scheduledAt: string;
	maxParticipants: number;
	/** Accepted participants, host included. */
	participantCount: number;
	visibility: EventVisibility;
	status: EventStatus;
	myRsvp: RsvpStatus | null;
	isHost: boolean;
	reminderSent: boolean;
	participants: EventParticipant[];
	createdAt: string;
}

/** Payload on STOMP `/topic/events/{eventId}` after a roster or status change. */
export interface EventLiveUpdate {
	eventId: string;
	participantCount: number;
	status: EventStatus;
	participants: EventParticipant[];
}

// ─── Match ─────────────────────────────────────────────────────────────────

export interface MatchRequest {
	id: string;
	game: GameSummary;
	availableFrom: string | null;
	availableTo: string | null;
	status: 'ACTIVE' | 'MATCHED' | 'CANCELLED' | 'EXPIRED';
	createdAt: string;
}

export interface MatchGroup {
	id: string;
	game: GameSummary;
	overlapStart: string | null;
	overlapEnd: string | null;
	status: 'PENDING' | 'ACCEPTED' | 'DISMISSED' | 'EXPIRED';
	members: User[];
	createdAt: string;
}
