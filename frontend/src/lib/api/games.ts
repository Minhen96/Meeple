import { api } from './client';
import type { ApiResponse, GameDetail, GameSearchResult, UserGame } from '$lib/types';

export interface UpdateCollectionPayload {
	isOwned?: boolean;
	isWishlisted?: boolean;
	isFavorited?: boolean;
	personalRating?: number | null;
	notes?: string | null;
}

export const gamesApi = {
	search: async (query: string): Promise<GameSearchResult[]> => {
		const res = await api.get<ApiResponse<GameSearchResult[]>>(
			`/api/v1/games/search?q=${encodeURIComponent(query)}`
		);
		return res.data;
	},

	browse: async (params: { 
		q?: string; 
		minPlayers?: number; maxPlayers?: number;
		minPlaytime?: number; maxPlaytime?: number;
		minComplexity?: number; maxComplexity?: number;
		minRating?: number;
		page?: number;
		sort?: string;
	}) => {
		const searchParams = new URLSearchParams();
		if (params.q) searchParams.set('q', params.q);
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
		return res.data;
	},

	getGame: async (id: string): Promise<GameDetail> => {
		const res = await api.get<ApiResponse<GameDetail>>(`/api/v1/games/${id}`);
		return res.data;
	},

	getMyCollection: async (): Promise<UserGame[]> => {
		const res = await api.get<ApiResponse<UserGame[]>>('/api/v1/users/me/games');
		return res.data;
	},

	updateCollection: async (gameId: string, payload: UpdateCollectionPayload): Promise<UserGame> => {
		const res = await api.put<ApiResponse<UserGame>>(`/api/v1/users/me/games/${gameId}`, payload);
		return res.data;
	},

	removeFromCollection: (gameId: string) =>
		api.delete<void>(`/api/v1/users/me/games/${gameId}`)
};
