import { api } from './client';
import type { ApiResponse } from '$lib/types';

// AuthResponse is what login/refresh return — a lightweight subset of the user profile
export interface AuthResponse {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	email: string;
}

export interface AvailabilityResponse {
	available: boolean;
}

export const authApi = {
	login: (emailOrUsername: string, password: string) =>
		api.post<ApiResponse<AuthResponse>>('/api/v1/auth/login', { emailOrUsername, password }),

	register: (email: string, username: string, password: string) =>
		api.post<ApiResponse<{ message: string }>>('/api/v1/auth/register', { email, username, password }),

	logout: () => api.post<void>('/api/v1/auth/logout'),

	refresh: () => api.post<ApiResponse<AuthResponse>>('/api/v1/auth/refresh'),

	checkUsername: async (username: string): Promise<boolean> => {
		const res = await api.get<ApiResponse<AvailabilityResponse>>(
			`/api/v1/auth/check-username?username=${encodeURIComponent(username)}`
		);
		return res.data.available;
	},

	checkEmail: async (email: string): Promise<boolean> => {
		const res = await api.get<ApiResponse<AvailabilityResponse>>(
			`/api/v1/auth/check-email?email=${encodeURIComponent(email)}`
		);
		return res.data.available;
	}
};
