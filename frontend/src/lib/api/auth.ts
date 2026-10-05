import { api } from './client';
import type { ReactivateRequest, SessionInfo } from '$lib/types';

export interface AuthResponse {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	email: string;
	onboardingCompleted?: boolean;
}

export const authApi = {
	login: (emailOrUsername: string, password: string) =>
		api.post<AuthResponse>('/api/v1/auth/login', { emailOrUsername, password }),

	register: (email: string, username: string, password: string) =>
		api.post<{ message: string }>('/api/v1/auth/register', { email, username, password }),

	logout: () => api.post<void>('/api/v1/auth/logout'),

	refresh: () => api.post<AuthResponse>('/api/v1/auth/refresh'),

	googleLogin: (idToken: string) => api.post<AuthResponse>('/api/v1/auth/google', { idToken }),

	/** Restores an account deleted less than 30 days ago and signs in. */
	reactivate: (body: ReactivateRequest) => api.post<AuthResponse>('/api/v1/auth/reactivate', body),

	verifyEmail: (token: string) => api.post<AuthResponse>('/api/v1/auth/verify-email', { token }),

	resendVerification: (email: string) =>
		api.post<{ message: string }>('/api/v1/auth/resend-verification', { email }),

	forgotPassword: (email: string) =>
		api.post<{ message: string }>('/api/v1/auth/forgot-password', { email }),

	resetPassword: (token: string, newPassword: string) =>
		api.post<{ message: string }>('/api/v1/auth/reset-password', { token, newPassword }),

	/** Applies an email change from the link sent to the new address. */
	confirmEmailChange: (token: string) =>
		api.post<{ message: string }>('/api/v1/auth/confirm-email-change', { token }),

	sessions: () => api.get<SessionInfo[]>('/api/v1/auth/sessions'),

	revokeSession: (id: string) => api.delete<void>(`/api/v1/auth/sessions/${encodeURIComponent(id)}`),

	revokeOtherSessions: () => api.post<{ revoked: number }>('/api/v1/auth/sessions/revoke-others'),

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
