import { api } from './client';
import type { HowToPlayApiResponse } from '$lib/types';

export const howToPlayApi = {
	get: (gameId: string) =>
		api.get<HowToPlayApiResponse>(`/api/v1/games/${gameId}/how-to-play`)
};
