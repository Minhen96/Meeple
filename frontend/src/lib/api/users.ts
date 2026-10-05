import { api, type ApiOptions } from './client';
import type {
	DataExport,
	DeleteAccountRequest,
	PaginatedResponse,
	PreferredLanguage,
	ProfileStats,
	User,
	UserSummary,
	UserSummaryWithStatus
} from '$lib/types';

export interface UpdateProfilePayload {
	displayName?: string;
	bio?: string;
	location?: string;
	avatarUrl?: string;
	onboardingCompleted?: boolean;
	/** Lowercase letters, digits and underscores; changeable once every 30 days. */
	username?: string;
	preferredLanguage?: PreferredLanguage;
	timezone?: string;
}

/** Profile field limits (FEATURES_COMPLETE section 12.1), mirrored from the backend. */
export const PROFILE_LIMITS = {
	displayNameMax: 50,
	bioMax: 200,
	locationMax: 100,
	usernameMin: 3,
	usernameMax: 20
} as const;

export const USERNAME_PATTERN = /^[a-z0-9][a-z0-9_]*$/;

/** Client-side check matching the backend's username rule; returns an error key or null. */
export function usernameProblem(value: string): 'tooShort' | 'tooLong' | 'invalid' | null {
	if (value.length < PROFILE_LIMITS.usernameMin) return 'tooShort';
	if (value.length > PROFILE_LIMITS.usernameMax) return 'tooLong';
	if (!USERNAME_PATTERN.test(value)) return 'invalid';
	return null;
}

/**
 * Name to show for a user reference. Deleted users (UserSummary.deleted) render as
 * `deletedLabel` ("Deleted User", localised by the caller).
 */
export function displayNameOf(
	user: Pick<UserSummary, 'displayName' | 'username'> & { deleted?: boolean },
	deletedLabel: string
): string {
	if (user.deleted) return deletedLabel;
	return user.displayName || user.username || deletedLabel;
}

export const usersApi = {
	getMe: (opts?: ApiOptions): Promise<User> => api.get<User>('/api/v1/users/me', opts),

	getUser: (id: string, opts?: ApiOptions): Promise<User> =>
		api.get<User>(`/api/v1/users/${encodeURIComponent(id)}`, opts),

	updateMe: (payload: UpdateProfilePayload): Promise<User> =>
		api.put<User>('/api/v1/users/me', payload),

	/** Schedules the account for deletion (30-day grace). Clears this device's auth cookies. */
	deleteMe: (body: DeleteAccountRequest) =>
		api.deleteWithBody<void>('/api/v1/users/me', body),

	/** Emails a confirmation link to `newEmail`; the email changes when it is opened. */
	changeEmail: (currentPassword: string, newEmail: string) =>
		api.post<{ message: string }>('/api/v1/users/me/change-email', { currentPassword, newEmail }),

	/** Starts (or returns the recent) data export; the download link is emailed. */
	requestExport: (): Promise<DataExport> => api.get<DataExport>('/api/v1/users/me/export'),

	/**
	 * People search by username or display name, with my friendship status for each row. The
	 * viewer, deleted accounts and blocked users (either way) are never returned.
	 */
	searchUsers: (
		q: string,
		page = 0,
		size = 20,
		opts?: ApiOptions
	): Promise<PaginatedResponse<UserSummaryWithStatus>> => {
		const params = new URLSearchParams({ q, page: String(page), size: String(size) });
		return api.get<PaginatedResponse<UserSummaryWithStatus>>(
			`/api/v1/users/search?${params.toString()}`,
			opts
		);
	},

	/**
	 * People you may know (max 10), ranked by games in common with my collection. Friends and
	 * pending requests are excluded, so every row's `friendshipStatus` is `none`.
	 */
	getSuggestions: (
		limit = 10,
		opts?: ApiOptions
	): Promise<PaginatedResponse<UserSummaryWithStatus>> =>
		api.get<PaginatedResponse<UserSummaryWithStatus>>(
			`/api/v1/users/suggestions?limit=${limit}`,
			opts
		),

	/** Profile stats bento (library package). */
	getStats: (id: string, opts?: ApiOptions): Promise<ProfileStats> =>
		api.get<ProfileStats>(`/api/v1/users/${encodeURIComponent(id)}/stats`, opts),

	/**
	 * Uploads an (already cropped) avatar through the backend to R2 and returns its public URL.
	 * Pass the URL to `updateMe({ avatarUrl })` to use it.
	 */
	uploadAvatar: async (file: File): Promise<string> => {
		const form = new FormData();
		form.append('file', file);
		const res = await api.post<{ publicUrl: string }>('/api/v1/upload/avatar', form);
		return res.publicUrl;
	},

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
