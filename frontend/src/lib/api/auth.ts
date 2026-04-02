import { api } from './client';

export interface AuthResponse {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	email: string;
}

export const authApi = {
	login: (emailOrUsername: string, password: string) =>
		api.post<AuthResponse>('/api/v1/auth/login', { emailOrUsername, password }),

	register: (email: string, username: string, password: string) =>
		api.post<{ message: string }>('/api/v1/auth/register', { email, username, password }),

	logout: () => api.post<void>('/api/v1/auth/logout'),

	refresh: () => api.post<AuthResponse>('/api/v1/auth/refresh'),

	checkUsername: async (username: string): Promise<boolean> => {
		const res = await api.get<{ available: boolean }>(
			`/api/v1/auth/check-username?username=${encodeURIComponent(username)}`
		);
		return res.available;
	},

	checkEmail: async (email: string): Promise<boolean> => {
		const res = await api.get<{ available: boolean }>(
			`/api/v1/auth/check-email?email=${encodeURIComponent(email)}`
		);
		return res.available;
	}
};
