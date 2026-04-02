import { api } from './client';
import type { ApiResponse, MyRuleNote } from '$lib/types';

export const ruleNotesApi = {
	submit: (gameId: string, content: string): Promise<MyRuleNote> =>
		api.post<MyRuleNote>(`/api/v1/games/${gameId}/rule-notes`, { content }),

	getMy: (gameId: string): Promise<MyRuleNote | null> =>
		api
			.get<MyRuleNote>(`/api/v1/games/${gameId}/rule-notes/my`)
			.catch((err) => {
				if (err?.response?.status === 204 || err?.response?.status === 404) return null;
				throw err;
			}),

	deleteMy: (gameId: string): Promise<void> =>
		api.delete(`/api/v1/games/${gameId}/rule-notes/my`).then(() => undefined)
};
