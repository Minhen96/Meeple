import { beforeEach, describe, expect, it, vi } from 'vitest';

const calls = vi.hoisted(() => [] as Array<{ method: string; path: string; body?: unknown }>);
vi.mock('./client', () => ({
	api: {
		get: vi.fn(async (path: string) => {
			calls.push({ method: 'GET', path });
			return path.endsWith('/unread-count') ? { count: 4 } : {};
		}),
		post: vi.fn(async (path: string, body?: unknown) => {
			calls.push({ method: 'POST', path, body });
		}),
		put: vi.fn(async (path: string, body?: unknown) => {
			calls.push({ method: 'PUT', path, body });
		}),
		delete: vi.fn(async (path: string) => {
			calls.push({ method: 'DELETE', path });
		})
	}
}));

import { fcmTokensApi, notificationsApi } from './notifications';

beforeEach(() => {
	calls.length = 0;
});

describe('notificationsApi', () => {
	it('builds the documented endpoints', async () => {
		await notificationsApi.list();
		await notificationsApi.list('2026-10-05T10:00:00.123456Z_abc', 10);
		await notificationsApi.getAll();
		expect(await notificationsApi.getUnreadCount()).toBe(4);
		await notificationsApi.markRead('n1');
		await notificationsApi.markAllRead();
		await notificationsApi.remove('n1');
		await notificationsApi.getPreferences();
		await notificationsApi.updatePreferences([
			{ type: 'POST_LIKE', inAppEnabled: true, pushEnabled: false }
		]);
		await notificationsApi.getSettings();
		await notificationsApi.updateSettings({
			quietHoursEnabled: true,
			quietHoursStart: '22:00',
			quietHoursEnd: '07:00',
			timezone: 'UTC'
		});

		expect(calls.map((c) => `${c.method} ${c.path}`)).toEqual([
			'GET /api/v1/notifications?limit=30',
			'GET /api/v1/notifications?limit=10&cursor=2026-10-05T10%3A00%3A00.123456Z_abc',
			'GET /api/v1/notifications?page=0&size=20',
			'GET /api/v1/notifications/unread-count',
			'PUT /api/v1/notifications/n1/read',
			'PUT /api/v1/notifications/read-all',
			'DELETE /api/v1/notifications/n1',
			'GET /api/v1/notifications/preferences',
			'PUT /api/v1/notifications/preferences',
			'GET /api/v1/notifications/settings',
			'PUT /api/v1/notifications/settings'
		]);
	});

	it('registers and unregisters device tokens (URL-encoded)', async () => {
		await fcmTokensApi.register('a:b/c', 'web', 'Chrome');
		await fcmTokensApi.unregister('a:b/c');
		expect(calls).toEqual([
			{
				method: 'POST',
				path: '/api/v1/users/me/fcm-tokens',
				body: { token: 'a:b/c', platform: 'web', deviceInfo: 'Chrome' }
			},
			{ method: 'DELETE', path: '/api/v1/users/me/fcm-tokens/a%3Ab%2Fc' }
		]);
	});
});
