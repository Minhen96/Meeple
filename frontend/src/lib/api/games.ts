import { api } from './client';
import type { ActivityLog, ApiResponse, GameDetail, GameSearchResult, PlayLog, UserGame } from '$lib/types';

export interface UpdateCollectionPayload {
	isOwned?: boolean;
	isFavorited?: boolean;
	personalRating?: number | null;
	notes?: string | null;
}

export const gamesApi = {
	search: async (query: string): Promise<GameSearchResult[]> => {
		const res = await api.get<GameSearchResult[]>(
			`/api/v1/games/search?q=${encodeURIComponent(query)}`
		);
		return res;
	},

	browse: async (params: {
		query?: string;
		genre?: string;
		minPlayers?: number;
		maxPlayers?: number;
		minPlaytime?: number; maxPlaytime?: number;
		minComplexity?: number; maxComplexity?: number;
		minRating?: number;
		page?: number;
		sort?: string;
	}) => {
		const searchParams = new URLSearchParams();
		if (params.query) searchParams.set('q', params.query);
		if (params.genre) searchParams.set('genre', params.genre);
		if (params.minPlayers) searchParams.set('minPlayers', params.minPlayers.toString());
		if (params.maxPlayers) searchParams.set('maxPlayers', params.maxPlayers.toString());
		if (params.minPlaytime) searchParams.set('minPlaytime', params.minPlaytime.toString());
		if (params.maxPlaytime) searchParams.set('maxPlaytime', params.maxPlaytime.toString());
		if (params.minComplexity) searchParams.set('minComplexity', params.minComplexity.toString());
		if (params.maxComplexity) searchParams.set('maxComplexity', params.maxComplexity.toString());
		if (params.minRating) searchParams.set('minRating', params.minRating.toString());
		if (params.page !== undefined) searchParams.set('page', params.page.toString());
		if (params.sort) searchParams.set('sort', params.sort);
		const res = await api.get<any>(`/api/v1/games?${searchParams.toString()}`);
		return res;
	},

	getGame: async (id: string): Promise<GameDetail> => {
		const res = await api.get<GameDetail>(`/api/v1/games/${id}`);
		return res;
	},

	getMyCollection: async (): Promise<UserGame[]> => {
		const res = await api.get<UserGame[]>('/api/v1/users/me/games');
		return res;
	},

	updateCollection: async (gameId: string, payload: UpdateCollectionPayload): Promise<UserGame> => {
		const res = await api.put<UserGame>(`/api/v1/users/me/games/${gameId}`, payload);
		return res;
	},

	removeFromCollection: (gameId: string) =>
		api.delete<void>(`/api/v1/users/me/games/${gameId}`),

	logPlay: async (gameId: string): Promise<UserGame> => {
		const res = await api.post<UserGame>(`/api/v1/users/me/games/${gameId}/log-play`, {});
		return res;
	},

	getPlays: async (gameId: string): Promise<PlayLog[]> => {
		const res = await api.get<PlayLog[]>(`/api/v1/users/me/games/${gameId}/plays`);
		return res;
	},

	getActivity: async (): Promise<ActivityLog[]> => {
		const res = await api.get<ActivityLog[]>('/api/v1/users/me/plays');
		return res;
	}
};
