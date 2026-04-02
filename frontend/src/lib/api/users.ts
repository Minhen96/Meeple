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
		const res = await api.get<User>('/api/v1/users/me');
		return res;
	},

	getUser: async (id: string): Promise<User> => {
		const res = await api.get<User>(`/api/v1/users/${id}`);
		return res;
	},

	updateMe: async (payload: UpdateProfilePayload): Promise<User> => {
		const res = await api.put<User>('/api/v1/users/me', payload);
		return res;
	},

	deleteMe: () => api.delete<void>('/api/v1/users/me'),

	checkUsername: async (username: string): Promise<boolean> => {
		try {
			const res = await api.get<{ available: boolean }>(
				`/api/v1/auth/check-username?username=${encodeURIComponent(username)}`
			);
		return res.available;
		} catch {
			return false;
		}
	}
};
