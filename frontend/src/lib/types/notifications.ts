// Owned by WP1 (notifications). Re-exported from ./index.ts; import from '$lib/types'.

// ─── Notification ──────────────────────────────────────────────────────────

/** Mirrors the backend NotificationType enum (docs/GAP_ANALYSIS.md section 6.4). */
export type NotificationType =
	| 'EVENT_INVITE'
	| 'EVENT_RSVP'
	| 'EVENT_LEAVE'
	| 'EVENT_KICKED'
	| 'EVENT_CANCELLED'
	| 'EVENT_UPDATED'
	| 'EVENT_REMINDER'
	| 'EVENT_COMPLETED'
	| 'MATCH_FOUND'
	| 'MATCH_ACCEPTED'
	| 'POST_LIKE'
	| 'POST_COMMENT'
	| 'COMMENT_MENTION'
	| 'POST_TAG'
	| 'FRIEND_REQUEST'
	| 'FRIEND_ACCEPTED'
	| 'RULE_NOTE_APPROVED'
	| 'RULE_NOTE_REJECTED'
	| 'RULEBOOK_APPROVED'
	| 'RULEBOOK_REJECTED'
	| 'RULEBOOK_UNDER_REVIEW'
	| 'BGG_IMPORT_COMPLETED';

export interface Notification {
	id: string;
	type: NotificationType;
	actorId: string | null;
	referenceId: string | null;
	referenceType: string | null;
	read: boolean;
	createdAt: string;
}
