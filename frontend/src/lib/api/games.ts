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
