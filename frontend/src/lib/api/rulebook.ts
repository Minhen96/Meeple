import { api } from './client';
import type { RulebookStatus } from '$lib/types';

export interface GenerateRulebookResult {
	status: 'generating' | 'not_found' | 'already_done';
}

export interface Rulebook {
	id: string;
	gameId: string;
	gameName: string;
	source: string;
	fileUrl: string | null;
	uploaderUsername: string | null;
	createdAt: string;
}

export interface UploadRulebookResult {
	status: 'queued' | 'already_done';
	queuePosition?: number;
}

export const rulebookApi = {
	getStatus: (gameId: string): Promise<RulebookStatus> =>
		api.get<RulebookStatus>(`/api/v1/games/${gameId}/rulebook/status`),

	generate: (gameId: string): Promise<GenerateRulebookResult> =>
		api.post<GenerateRulebookResult>(`/api/v1/games/${gameId}/rulebook/generate`, {}),

	getRulebook: (rulebookId: string): Promise<Rulebook> =>
		api.get<Rulebook>(`/api/v1/rulebooks/${rulebookId}`),

	upload: (gameId: string, file: File): Promise<UploadRulebookResult> => {
		const form = new FormData();
		form.append('file', file);
		return api.post<UploadRulebookResult>(`/api/v1/games/${gameId}/rulebook/upload`, form);
	}
};
