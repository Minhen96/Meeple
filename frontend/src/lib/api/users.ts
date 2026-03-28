import { api } from './client';
import type { ApiResponse, User } from '$lib/types';

export interface UpdateProfilePayload {
	displayName?: string;
	bio?: string;
	location?: string;
	avatarUrl?: string;
	onboardingCompleted?: boolean;
}

export const usersApi = {
	getMe: async (): Promise<User> => {
		const res = await api.get<ApiResponse<User>>('/api/v1/users/me');
		return res.data;
	},

	getUser: async (id: string): Promise<User> => {
		const res = await api.get<ApiResponse<User>>(`/api/v1/users/${id}`);
		return res.data;
	},

	updateMe: async (payload: UpdateProfilePayload): Promise<User> => {
		const res = await api.put<ApiResponse<User>>('/api/v1/users/me', payload);
		return res.data;
	},

	deleteMe: () => api.delete<void>('/api/v1/users/me'),

	checkUsername: async (username: string): Promise<boolean> => {
		try {
			const res = await api.get<{ data: { available: boolean } }>(
				`/api/v1/auth/check-username?username=${encodeURIComponent(username)}`
			);
			return res.data.available;
		} catch {
			return false;
		}
	}
};
