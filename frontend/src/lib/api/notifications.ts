import { api } from './client';
import type {
	CursorPage,
	Notification,
	NotificationPreference,
	NotificationSettings,
	PaginatedResponse,
	PushPlatform
} from '$lib/types';

const BASE = '/api/v1/notifications';

export const notificationsApi = {
	/** Cursor page, newest first. Pass the previous `nextCursor` to continue. */
	list: (cursor: string | null = null, limit = 30): Promise<CursorPage<Notification>> => {
		const params = new URLSearchParams({ limit: String(limit) });
		if (cursor) params.set('cursor', cursor);
		return api.get<CursorPage<Notification>>(`${BASE}?${params.toString()}`);
	},

	/** Legacy offset page (`page` is 0-based) in the `{data, meta}` shape. */
	getAll: (page = 0, size = 20): Promise<PaginatedResponse<Notification>> =>
		api.get<PaginatedResponse<Notification>>(`${BASE}?page=${page}&size=${size}`),

	getUnreadCount: async (): Promise<number> => {
		const res = await api.get<{ count: number }>(`${BASE}/unread-count`);
		return res.count;
	},

	markRead: (id: string) => api.put<void>(`${BASE}/${encodeURIComponent(id)}/read`),

	markAllRead: () => api.put<void>(`${BASE}/read-all`, {}),

	remove: (id: string) => api.delete<void>(`${BASE}/${encodeURIComponent(id)}`),

	getPreferences: () => api.get<NotificationPreference[]>(`${BASE}/preferences`),

	updatePreferences: (preferences: NotificationPreference[]) =>
		api.put<NotificationPreference[]>(`${BASE}/preferences`, preferences),

	getSettings: () => api.get<NotificationSettings>(`${BASE}/settings`),

	updateSettings: (settings: NotificationSettings) =>
		api.put<NotificationSettings>(`${BASE}/settings`, settings)
};

/** Push device registration (POST/DELETE /api/v1/users/me/fcm-tokens). */
export const fcmTokensApi = {
	register: (token: string, platform: PushPlatform, deviceInfo?: string) =>
		api.post<void>('/api/v1/users/me/fcm-tokens', {
			token,
			platform,
			deviceInfo
		}),

	unregister: (token: string) =>
		api.delete<void>(`/api/v1/users/me/fcm-tokens/${encodeURIComponent(token)}`)
};
