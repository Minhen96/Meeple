// Owned by WP2 (events, matching). Re-exported from ./index.ts; import from '$lib/types'.

import type { User } from './account';
import type { GameSummary } from './library';

// ─── Event ─────────────────────────────────────────────────────────────────
// Maps to EventResponse — backend returns uppercase enum names

export interface Event {
	id: string;
	host: {
		id: string;
		username: string;
		displayName: string | null;
		avatarUrl: string | null;
	};
	game: GameSummary | null;
	title: string;
	description: string | null;
	location: string | null;
	scheduledAt: string;
	maxParticipants: number;
	participantCount: number;
	visibility: 'PUBLIC' | 'FRIENDS' | 'INVITE_ONLY';
	status: 'OPEN' | 'FULL' | 'COMPLETED' | 'CANCELLED';
	myRsvp: 'ACCEPTED' | 'DECLINED' | 'INVITED' | null;
	createdAt: string;
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
