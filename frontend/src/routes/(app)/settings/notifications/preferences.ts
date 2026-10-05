import type { NotificationPreference, NotificationType } from '$lib/types';

/**
 * The preferences table groups notification types into the rows of SCREENS_AND_STATES section
 * 11.3; toggling a row sets every type in it. A row is on when all of its types are on.
 */
export type PreferenceCategory =
	| 'eventInvites'
	| 'eventUpdates'
	| 'eventReminders'
	| 'matchFound'
	| 'friendRequests'
	| 'postLiked'
	| 'postComment'
	| 'commentMention'
	| 'postTagged'
	| 'library';

export const PREFERENCE_CATEGORIES: ReadonlyArray<{
	key: PreferenceCategory;
	types: readonly NotificationType[];
}> = [
	{ key: 'eventInvites', types: ['EVENT_INVITE'] },
	{
		key: 'eventUpdates',
		types: [
			'EVENT_RSVP',
			'EVENT_LEAVE',
			'EVENT_KICKED',
			'EVENT_CANCELLED',
			'EVENT_UPDATED',
			'EVENT_COMPLETED'
		]
	},
	{ key: 'eventReminders', types: ['EVENT_REMINDER'] },
	{ key: 'matchFound', types: ['MATCH_FOUND', 'MATCH_ACCEPTED'] },
	{ key: 'friendRequests', types: ['FRIEND_REQUEST', 'FRIEND_ACCEPTED'] },
	{ key: 'postLiked', types: ['POST_LIKE'] },
	{ key: 'postComment', types: ['POST_COMMENT'] },
	{ key: 'commentMention', types: ['COMMENT_MENTION'] },
	{ key: 'postTagged', types: ['POST_TAG'] },
	{
		key: 'library',
		types: [
			'RULE_NOTE_APPROVED',
			'RULE_NOTE_REJECTED',
			'RULEBOOK_APPROVED',
			'RULEBOOK_REJECTED',
			'RULEBOOK_UNDER_REVIEW',
			'BGG_IMPORT_COMPLETED'
		]
	}
];

export type Channel = 'inAppEnabled' | 'pushEnabled';

/** Missing types count as enabled (the backend default). */
export function categoryEnabled(
	prefs: readonly NotificationPreference[],
	types: readonly NotificationType[],
	channel: Channel
): boolean {
	return types.every((type) => prefs.find((p) => p.type === type)?.[channel] ?? true);
}

/** The rows to PUT when a category's channel is switched. */
export function categoryUpdate(
	prefs: readonly NotificationPreference[],
	types: readonly NotificationType[],
	channel: Channel,
	enabled: boolean
): NotificationPreference[] {
	return types.map((type) => {
		const current = prefs.find((p) => p.type === type) ?? {
			type,
			inAppEnabled: true,
			pushEnabled: true
		};
		return { ...current, [channel]: enabled };
	});
}

/** Merge updated rows into the list (by type). */
export function mergePreferences(
	prefs: readonly NotificationPreference[],
	updates: readonly NotificationPreference[]
): NotificationPreference[] {
	const byType = new Map(prefs.map((p) => [p.type, p]));
	updates.forEach((u) => byType.set(u.type, u));
	return [...byType.values()];
}

/** The browser's IANA time zone, or null when unavailable. */
export function browserTimeZone(): string | null {
	try {
		return Intl.DateTimeFormat().resolvedOptions().timeZone || null;
	} catch {
		return null;
	}
}
