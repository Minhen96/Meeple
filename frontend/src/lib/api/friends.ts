import { api, type ApiOptions } from './client';
import type {
	FriendRequest,
	FriendStatus,
	PaginatedResponse,
	ReportTargetType,
	SearchResults,
	SearchType,
	SuggestedUser,
	User,
	UserSummary,
	UserSummaryWithStatus
} from '$lib/types';

export const friendsApi = {
	/** Sends a request; if they already asked me, this accepts theirs (status ACCEPTED). */
	sendRequest: (userId: string): Promise<FriendRequest> =>
		api.post<FriendRequest>(`/api/v1/users/${userId}/friend-request`, {}),

	/** Withdraws the pending request I sent to this user. */
	cancelTo: (userId: string) => api.delete<void>(`/api/v1/users/${userId}/friend-request`),

	getStatus: (userId: string, opts?: ApiOptions): Promise<FriendStatus> =>
		api.get<FriendStatus>(`/api/v1/users/${userId}/friend-status`, opts),

	accept: (requestId: string): Promise<FriendRequest> =>
		api.post<FriendRequest>(`/api/v1/friend-requests/${requestId}/accept`, {}),

	decline: (requestId: string): Promise<FriendRequest> =>
		api.post<FriendRequest>(`/api/v1/friend-requests/${requestId}/decline`, {}),

	cancel: (requestId: string) => api.delete<void>(`/api/v1/friend-requests/${requestId}`),

	unfriend: (userId: string) => api.delete<void>(`/api/v1/friends/${userId}`),

	getFriends: (page = 0, size = 20, opts?: ApiOptions): Promise<PaginatedResponse<User>> =>
		api.get<PaginatedResponse<User>>(`/api/v1/friends?page=${page}&size=${size}`, opts),

	getReceived: (
		page = 0,
		size = 20,
		opts?: ApiOptions
	): Promise<PaginatedResponse<FriendRequest>> =>
		api.get<PaginatedResponse<FriendRequest>>(
			`/api/v1/friend-requests/received?page=${page}&size=${size}`,
			opts
		),

	getSent: (page = 0, size = 20, opts?: ApiOptions): Promise<PaginatedResponse<FriendRequest>> =>
		api.get<PaginatedResponse<FriendRequest>>(
			`/api/v1/friend-requests/sent?page=${page}&size=${size}`,
			opts
		),

	blockUser: (userId: string) => api.post<void>(`/api/v1/users/${userId}/block`, {}),
	unblockUser: (userId: string) => api.delete<void>(`/api/v1/users/${userId}/block`),
	getBlocked: (opts?: ApiOptions): Promise<UserSummary[]> =>
		api.get<UserSummary[]>('/api/v1/users/me/blocked', opts),

	/** People search with friendship status; blocked users are never returned. */
	searchUsers: async (
		q: string,
		limit = 20,
		opts?: ApiOptions
	): Promise<UserSummaryWithStatus[]> => {
		const res = await searchApi.search(q, { type: 'users', limit }, opts);
		return res.users;
	},

	/** People you may know, ranked by games in common (max 10). */
	getSuggestions: (limit = 10, opts?: ApiOptions): Promise<SuggestedUser[]> =>
		api.get<SuggestedUser[]>(`/api/v1/friends/suggestions?limit=${limit}`, opts)
};

export const searchApi = {
	/** Unified search for the overlay: up to `limit` (default 3, max 20) games, players and events. */
	search: (
		q: string,
		options: { type?: SearchType; limit?: number } = {},
		opts?: ApiOptions
	): Promise<SearchResults> => {
		const params = new URLSearchParams({
			q,
			limit: String(options.limit ?? 3),
			type: options.type ?? 'all'
		});
		return api.get<SearchResults>(`/api/v1/search?${params.toString()}`, opts);
	}
};

export const reportsApi = {
	/** 201 even when already reported; 429 REPORT_LIMIT_EXCEEDED after 5 per day. */
	report: (targetType: ReportTargetType, targetId: string, reason: string) =>
		api.post<void>('/api/v1/reports', { targetType, targetId, reason })
};
