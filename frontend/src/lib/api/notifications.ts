import { api } from './client';
import type { Notification, PaginatedResponse } from '$lib/types';

export const notificationsApi = {
	getAll: async (page = 0, size = 20): Promise<PaginatedResponse<Notification>> => {
		const res = await api.get<PaginatedResponse<Notification>>(
			`/api/v1/notifications?page=${page}&size=${size}`
		);
		return res;
	},

	getUnreadCount: async (): Promise<number> => {
		const res = await api.get<{ data: { count: number } }>('/api/v1/notifications/unread-count');
		return res.data.count;
	},

	markAllRead: () => api.put<void>('/api/v1/notifications/read-all', {})
};
