import { api } from './client';

export interface RulebookStatus {
	hasRulebook: boolean;
}

export interface GenerateRulebookResult {
	status: 'generating' | 'not_found' | 'already_done';
}

export const rulebookApi = {
	getStatus: (gameId: string): Promise<RulebookStatus> =>
		api.get<RulebookStatus>(`/api/v1/games/${gameId}/rulebook/status`),

	generate: (gameId: string): Promise<GenerateRulebookResult> =>
		api.post<GenerateRulebookResult>(`/api/v1/games/${gameId}/rulebook/generate`)
};
