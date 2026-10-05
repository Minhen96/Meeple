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

/** Who triggered a notification. A deleted actor keeps only its id (`deleted: true`). */
export interface NotificationActor {
	id: string;
	username: string | null;
	displayName: string | null;
	avatarUrl: string | null;
	deleted: boolean;
}

/** Server-rendered extras; `path` is the in-app deep link to open on tap. */
export interface NotificationData {
	path: string;
	count?: number;
	[key: string]: unknown;
}

/** NotificationDto (docs/GAP_ANALYSIS.md section 6.1). */
export interface Notification {
	id: string;
	type: NotificationType;
	actor: NotificationActor | null;
	referenceId: string | null;
	referenceType: string | null;
	title: string;
	body: string | null;
	data: NotificationData;
	read: boolean;
	createdAt: string;
}

/** Frame on `/user/queue/notifications` (section 6.3). */
export interface NotificationWsPayload {
	notification: Notification;
	unreadCount: number;
}

/** One row of GET/PUT /notifications/preferences. */
export interface NotificationPreference {
	type: NotificationType;
	inAppEnabled: boolean;
	pushEnabled: boolean;
}

/** GET/PUT /notifications/settings; times are "HH:mm". */
export interface NotificationSettings {
	quietHoursEnabled: boolean;
	quietHoursStart: string | null;
	quietHoursEnd: string | null;
	timezone: string | null;
}

export type PushPlatform = 'web' | 'ios' | 'android';
