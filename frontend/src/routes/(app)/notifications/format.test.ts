import { afterEach, describe, expect, it } from 'vitest';
import { DEFAULT_LOCALE, setLocale } from '$lib/i18n';
import en from '$lib/i18n/notif';
import zh from '$lib/i18n/zh-CN/notif';
import type { Notification } from '$lib/types';
import { actorName, relativeTime, typeIcon } from './format';

afterEach(() => setLocale(DEFAULT_LOCALE));

const now = new Date('2026-10-05T12:00:00Z');

describe('relativeTime', () => {
	it('formats seconds to days, then a date', () => {
		expect(relativeTime('2026-10-05T11:59:30Z', now)).toBe('just now');
		expect(relativeTime('2026-10-05T11:55:00Z', now)).toBe('5m');
		expect(relativeTime('2026-10-05T09:00:00Z', now)).toBe('3h');
		expect(relativeTime('2026-10-03T12:00:00Z', now)).toBe('2d');
		expect(relativeTime('2026-09-01T12:00:00Z', now)).not.toBe('');
		expect(relativeTime('garbage', now)).toBe('');
		setLocale('zh-CN');
		expect(relativeTime('2026-10-05T09:00:00Z', now)).toBe('3 小时前');
	});
});

describe('actorName and typeIcon', () => {
	const base: Notification = {
		id: '1',
		type: 'FRIEND_REQUEST',
		actor: {
			id: 'u',
			username: 'ana',
			displayName: 'Ana',
			avatarUrl: null,
			deleted: false
		},
		referenceId: null,
		referenceType: null,
		title: 't',
		body: null,
		data: { path: '/' },
		read: false,
		createdAt: '2026-10-05T12:00:00Z'
	};

	it('prefers display name, then username; deleted actors are anonymised', () => {
		expect(actorName(base)).toBe('Ana');
		expect(actorName({ ...base, actor: { ...base.actor!, displayName: null } })).toBe('ana');
		expect(actorName({ ...base, actor: { ...base.actor!, deleted: true } })).toBe('Deleted User');
		expect(actorName({ ...base, actor: null })).toBeNull();
	});

	it('maps types to icons', () => {
		expect(typeIcon('EVENT_REMINDER')).toBe('event');
		expect(typeIcon('MATCH_FOUND')).toBe('groups');
		expect(typeIcon('POST_LIKE')).toBe('favorite');
		expect(typeIcon('COMMENT_MENTION')).toBe('chat_bubble');
		expect(typeIcon('POST_TAG')).toBe('sell');
		expect(typeIcon('FRIEND_ACCEPTED')).toBe('person_add');
		expect(typeIcon('BGG_IMPORT_COMPLETED')).toBe('library_add');
		expect(typeIcon('RULEBOOK_APPROVED')).toBe('menu_book');
	});
});

describe('notif messages', () => {
	it('has a zh-CN translation for every key', () => {
		expect(Object.keys(zh).sort()).toEqual(Object.keys(en).sort());
	});
});
