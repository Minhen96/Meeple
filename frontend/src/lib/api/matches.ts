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
		const res = await api.post<MatchRequest>('/api/v1/matches/requests', payload);
		return res;
	},

	cancelRequest: (id: string) => api.delete<void>(`/api/v1/matches/requests/${id}`),

	listMyRequests: async (): Promise<MatchRequest[]> => {
		const res = await api.get<MatchRequest[]>('/api/v1/matches/requests/mine');
		return res;
	},

	getSuggestions: async (): Promise<MatchGroup[]> => {
		const res = await api.get<MatchGroup[]>('/api/v1/matches/suggestions');
		return res;
	},

	acceptMatch: async (groupId: string): Promise<Event> => {
		const res = await api.post<Event>(`/api/v1/matches/${groupId}/accept`, {});
		return res;
	},

	dismissMatch: (groupId: string) => api.post<void>(`/api/v1/matches/${groupId}/dismiss`, {})
};
