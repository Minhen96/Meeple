import { api } from './client';
import type { ApiResponse, RulebookStatus } from '$lib/types';

export interface GenerateRulebookResult {
	status: 'generating' | 'not_found' | 'already_done';
}

export interface UploadRulebookResult {
	status: 'queued' | 'already_done';
	rulebookId?: string;
	queuePosition?: number;
}

export const rulebookApi = {
	getStatus: (gameId: string): Promise<RulebookStatus> =>
		api
			.get<ApiResponse<RulebookStatus>>(`/api/v1/games/${gameId}/rulebook/status`)
			.then((r) => r.data),

	generate: (gameId: string): Promise<GenerateRulebookResult> =>
		api
			.post<ApiResponse<GenerateRulebookResult>>(`/api/v1/games/${gameId}/rulebook/generate`)
			.then((r) => r.data),

	upload: (gameId: string, file: File): Promise<UploadRulebookResult> => {
		const form = new FormData();
		form.append('file', file);
		return fetch(`${import.meta.env.VITE_API_URL}/api/v1/games/${gameId}/rulebook`, {
			method: 'POST',
			credentials: 'include',
			body: form
		}).then((r) => r.json());
	}
};
