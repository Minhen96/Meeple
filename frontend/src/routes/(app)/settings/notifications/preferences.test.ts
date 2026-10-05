import { describe, expect, it } from 'vitest';
import type { NotificationPreference, NotificationType } from '$lib/types';
import {
	PREFERENCE_CATEGORIES,
	browserTimeZone,
	categoryEnabled,
	categoryUpdate,
	mergePreferences
} from './preferences';

const ALL_TYPES: NotificationType[] = [
	'EVENT_INVITE',
	'EVENT_RSVP',
	'EVENT_LEAVE',
	'EVENT_KICKED',
	'EVENT_CANCELLED',
	'EVENT_UPDATED',
	'EVENT_REMINDER',
	'EVENT_COMPLETED',
	'MATCH_FOUND',
	'MATCH_ACCEPTED',
	'POST_LIKE',
	'POST_COMMENT',
	'COMMENT_MENTION',
	'POST_TAG',
	'FRIEND_REQUEST',
	'FRIEND_ACCEPTED',
	'RULE_NOTE_APPROVED',
	'RULE_NOTE_REJECTED',
	'RULEBOOK_APPROVED',
	'RULEBOOK_REJECTED',
	'RULEBOOK_UNDER_REVIEW',
	'BGG_IMPORT_COMPLETED'
];

describe('preference categories', () => {
	it('cover every notification type exactly once', () => {
		const covered = PREFERENCE_CATEGORIES.flatMap((c) => c.types);
		expect([...covered].sort()).toEqual([...ALL_TYPES].sort());
	});

	it('a category is on only when all of its types are on (missing = default on)', () => {
		const prefs: NotificationPreference[] = [
			{ type: 'MATCH_FOUND', inAppEnabled: true, pushEnabled: false },
			{ type: 'MATCH_ACCEPTED', inAppEnabled: true, pushEnabled: true }
		];
		expect(categoryEnabled(prefs, ['MATCH_FOUND', 'MATCH_ACCEPTED'], 'inAppEnabled')).toBe(true);
		expect(categoryEnabled(prefs, ['MATCH_FOUND', 'MATCH_ACCEPTED'], 'pushEnabled')).toBe(false);
		expect(categoryEnabled([], ['POST_LIKE'], 'pushEnabled')).toBe(true);
	});

	it('updates set one channel for every type and keep the other', () => {
		const prefs: NotificationPreference[] = [
			{ type: 'MATCH_FOUND', inAppEnabled: false, pushEnabled: true }
		];
		const update = categoryUpdate(prefs, ['MATCH_FOUND', 'MATCH_ACCEPTED'], 'pushEnabled', false);
		expect(update).toEqual([
			{ type: 'MATCH_FOUND', inAppEnabled: false, pushEnabled: false },
			{ type: 'MATCH_ACCEPTED', inAppEnabled: true, pushEnabled: false }
		]);
		const merged = mergePreferences(prefs, update);
		expect(merged).toHaveLength(2);
		expect(merged.find((p) => p.type === 'MATCH_FOUND')?.pushEnabled).toBe(false);
	});

	it('reads the browser time zone', () => {
		expect(typeof browserTimeZone()).toBe('string');
	});
});
