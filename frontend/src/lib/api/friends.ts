import { api } from './client';
import type { FriendRequest, FriendStatus, PaginatedResponse, User } from '$lib/types';

export const friendsApi = {
	sendRequest: async (userId: string): Promise<FriendRequest> => {
		const res = await api.post<FriendRequest>(`/api/v1/users/${userId}/friend-request`, {});
		return res;
	},

	getStatus: async (userId: string): Promise<FriendStatus> => {
		const res = await api.get<FriendStatus>(`/api/v1/users/${userId}/friend-status`);
		return res;
	},

	accept: async (requestId: string): Promise<FriendRequest> => {
		const res = await api.post<FriendRequest>(`/api/v1/friends/requests/${requestId}/accept`, {});
		return res;
	},

	decline: async (requestId: string): Promise<FriendRequest> => {
		const res = await api.post<FriendRequest>(`/api/v1/friends/requests/${requestId}/decline`, {});
		return res;
	},

	unfriend: (userId: string) => api.delete<void>(`/api/v1/friends/${userId}`),

	getFriends: async (page = 0, size = 20): Promise<PaginatedResponse<User>> => {
		const res = await api.get<PaginatedResponse<User>>(`/api/v1/friends?page=${page}&size=${size}`);
		return res;
	},

	getReceived: async (page = 0, size = 20): Promise<PaginatedResponse<FriendRequest>> => {
		const res = await api.get<PaginatedResponse<FriendRequest>>(`/api/v1/friend-requests/received?page=${page}&size=${size}`);
		return res;
	},

	getSent: async (page = 0, size = 20): Promise<PaginatedResponse<FriendRequest>> => {
		const res = await api.get<PaginatedResponse<FriendRequest>>(`/api/v1/friend-requests/sent?page=${page}&size=${size}`);
		return res;
	},

	blockUser: (userId: string) => api.post<void>(`/api/v1/users/${userId}/block`, {}),
	unblockUser: (userId: string) => api.delete<void>(`/api/v1/users/${userId}/block`),

	searchUsers: async (q: string, page = 0, size = 20): Promise<PaginatedResponse<User>> => {
		const res = await api.get<PaginatedResponse<User>>(`/api/v1/users/search?q=${encodeURIComponent(q)}&page=${page}&size=${size}`);
		return res;
	},

	getSuggestions: async (page = 0, size = 10): Promise<PaginatedResponse<User>> => {
		const res = await api.get<PaginatedResponse<User>>(`/api/v1/users/suggestions?page=${page}&size=${size}`);
		return res;
	}
};
