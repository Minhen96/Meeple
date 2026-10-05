import { beforeEach, describe, expect, it } from 'vitest';
import { get } from 'svelte/store';
import type { Notification } from '$lib/types';
import {
	addNotification,
	appendNotifications,
	applyNotificationFrame,
	groupNotifications,
	handleNotificationFrame,
	markAllRead,
	markRead,
	notificationCount,
	notificationHref,
	notifications,
	parseNotificationFrame,
	removeNotification,
	resetNotifications,
	setUnreadCount,
	unreadCount
} from './notifications';

function n(id: string, overrides: Partial<Notification> = {}): Notification {
	return {
		id,
		type: 'POST_LIKE',
		actor: null,
		referenceId: null,
		referenceType: null,
		title: 'New Like',
		body: 'Ana liked your post',
		data: { path: '/posts/1' },
		read: false,
		createdAt: '2026-10-05T10:00:00Z',
		...overrides
	};
}

beforeEach(() => resetNotifications());

describe('badge count', () => {
	it('falls back to unread loaded items until the server count is known', () => {
		notifications.set([n('a'), n('b', { read: true })]);
		expect(get(notificationCount)).toBe(1);
		setUnreadCount(7);
		expect(get(notificationCount)).toBe(7);
		setUnreadCount(-3);
		expect(get(unreadCount)).toBe(0);
	});

	it('markRead decrements only for an unread item, markAllRead zeroes', () => {
		notifications.set([n('a'), n('b', { read: true })]);
		setUnreadCount(5);
		markRead('a');
		expect(get(unreadCount)).toBe(4);
		markRead('a');
		markRead('b');
		markRead('missing');
		expect(get(unreadCount)).toBe(4);
		markAllRead();
		expect(get(unreadCount)).toBe(0);
		expect(get(notifications).every((x) => x.read)).toBe(true);
	});

	it('removing an unread item decrements', () => {
		notifications.set([n('a'), n('b', { read: true })]);
		setUnreadCount(2);
		removeNotification('b');
		expect(get(unreadCount)).toBe(2);
		removeNotification('a');
		expect(get(unreadCount)).toBe(1);
		expect(get(notifications)).toEqual([]);
	});
});

describe('list updates', () => {
	it('prepends new items and replaces a batched like in place of its old copy', () => {
		notifications.set([n('a'), n('b')]);
		addNotification(n('b', { body: 'Ana and 1 other liked your post' }));
		expect(get(notifications).map((x) => x.id)).toEqual(['b', 'a']);
		expect(get(notifications)[0].body).toBe('Ana and 1 other liked your post');
	});

	it('appends older pages without duplicates', () => {
		notifications.set([n('a'), n('b')]);
		appendNotifications([n('b'), n('c')]);
		expect(get(notifications).map((x) => x.id)).toEqual(['a', 'b', 'c']);
	});
});

describe('WebSocket frames', () => {
	it('applies {notification, unreadCount}', () => {
		applyNotificationFrame({ notification: n('x'), unreadCount: 3 });
		expect(get(notifications)[0].id).toBe('x');
		expect(get(notificationCount)).toBe(3);
	});

	it('parses the new frame and a legacy bare notification, rejecting garbage', () => {
		const framed = parseNotificationFrame(JSON.stringify({ notification: n('x'), unreadCount: 2 }));
		expect(framed?.unreadCount).toBe(2);
		expect(framed?.notification.id).toBe('x');

		const legacy = parseNotificationFrame(
			JSON.stringify({
				id: 'y',
				type: 'FRIEND_REQUEST',
				read: false,
				createdAt: '2026-10-05T10:00:00Z'
			})
		);
		expect(legacy?.unreadCount).toBeNull();
		expect(legacy?.notification.data.path).toBe('/notifications');
		expect(legacy?.notification.actor).toBeNull();

		expect(parseNotificationFrame('not json')).toBeNull();
		expect(parseNotificationFrame('{"notification":{"id":1}}')).toBeNull();
		expect(parseNotificationFrame('null')).toBeNull();
	});

	it('handles a raw frame; a legacy frame bumps a known count', () => {
		setUnreadCount(1);
		expect(handleNotificationFrame(JSON.stringify({ notification: n('x'), unreadCount: 4 }))).toBe(
			true
		);
		expect(get(unreadCount)).toBe(4);
		expect(
			handleNotificationFrame(
				JSON.stringify({
					id: 'y',
					type: 'FRIEND_REQUEST',
					read: false,
					createdAt: '2026-10-05T10:00:00Z'
				})
			)
		).toBe(true);
		expect(get(unreadCount)).toBe(5);
		expect(handleNotificationFrame('{')).toBe(false);
	});
});

describe('groupNotifications', () => {
	const now = new Date(2026, 9, 5, 15, 0, 0); // local time, Monday 5 Oct 2026 15:00

	it('splits into Today, This Week and Earlier keeping order and skipping empty groups', () => {
		const today1 = n('t1', {
			createdAt: new Date(2026, 9, 5, 14, 0).toISOString()
		});
		const today2 = n('t2', {
			createdAt: new Date(2026, 9, 5, 0, 0).toISOString()
		});
		const week1 = n('w1', {
			createdAt: new Date(2026, 9, 4, 23, 59).toISOString()
		});
		const week2 = n('w2', {
			createdAt: new Date(2026, 8, 29, 0, 0).toISOString()
		});
		const old = n('o1', {
			createdAt: new Date(2026, 8, 28, 23, 59).toISOString()
		});
		const broken = n('o2', { createdAt: 'nope' });

		const groups = groupNotifications([today1, today2, week1, week2, old, broken], now);
		expect(groups.map((g) => g.key)).toEqual(['today', 'thisWeek', 'earlier']);
		expect(groups[0].items.map((x) => x.id)).toEqual(['t1', 't2']);
		expect(groups[1].items.map((x) => x.id)).toEqual(['w1', 'w2']);
		expect(groups[2].items.map((x) => x.id)).toEqual(['o1', 'o2']);

		expect(groupNotifications([week1], now).map((g) => g.key)).toEqual(['thisWeek']);
		expect(groupNotifications([], now)).toEqual([]);
	});
});

describe('notificationHref', () => {
	it('uses data.path for in-app paths only', () => {
		expect(notificationHref(n('a', { data: { path: '/events/1' } }))).toBe('/events/1');
		expect(notificationHref(n('a', { data: { path: 'https://evil.test' } }))).toBe(
			'/notifications'
		);
		expect(notificationHref(n('a', { data: { path: '//evil.test' } }))).toBe('/notifications');
		expect(notificationHref(n('a', { data: { path: '/\\evil' } }))).toBe('/notifications');
	});
});
