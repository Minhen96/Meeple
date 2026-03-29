import { api } from './client';
import type { MatchRequest, MatchGroup } from '$lib/types';
import type { Event } from '$lib/types';

export interface CreateMatchRequestPayload {
	gameId: string;
	availableFrom?: string;
	availableTo?: string;
}

export const matchesApi = {
	createRequest: async (payload: CreateMatchRequestPayload): Promise<MatchRequest> => {
		const res = await api.post<{ data: MatchRequest }>('/api/v1/matches/requests', payload);
		return res.data;
	},

	cancelRequest: (id: string) => api.delete<void>(`/api/v1/matches/requests/${id}`),

	listMyRequests: async (): Promise<MatchRequest[]> => {
		const res = await api.get<{ data: MatchRequest[] }>('/api/v1/matches/requests/mine');
		return res.data;
	},

	getSuggestions: async (): Promise<MatchGroup[]> => {
		const res = await api.get<{ data: MatchGroup[] }>('/api/v1/matches/suggestions');
		return res.data;
	},

	acceptMatch: async (groupId: string): Promise<Event> => {
		const res = await api.post<{ data: Event }>(`/api/v1/matches/${groupId}/accept`, {});
		return res.data;
	},

	dismissMatch: (groupId: string) => api.post<void>(`/api/v1/matches/${groupId}/dismiss`, {})
};
