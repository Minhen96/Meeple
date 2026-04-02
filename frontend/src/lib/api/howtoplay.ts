import { api } from './client';
import type { ApiResponse, HowToPlayApiResponse } from '$lib/types';

export const howToPlayApi = {
	get: (gameId: string): Promise<HowToPlayApiResponse> =>
		api.get<HowToPlayApiResponse>(`/api/v1/games/${gameId}/how-to-play`),

	generate: (gameId: string): Promise<HowToPlayApiResponse> =>
		api.post<HowToPlayApiResponse>(`/api/v1/games/${gameId}/how-to-play/generate`)
};
