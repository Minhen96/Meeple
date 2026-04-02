import { api } from './client';
import type { ApiResponse, HowToPlayApiResponse } from '$lib/types';

export const howToPlayApi = {
	get: (gameId: string) =>
		api.get<ApiResponse<HowToPlayApiResponse>>(`/api/v1/games/${gameId}/how-to-play`).then((r) => r.data)
};
