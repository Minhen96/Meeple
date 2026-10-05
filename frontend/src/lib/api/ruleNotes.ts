import { api, ApiRequestError } from './client';
import type { MyRuleNote } from '$lib/types';

export const ruleNotesApi = {
	submit: (gameId: string, content: string): Promise<MyRuleNote> =>
		api.post<MyRuleNote>(`/api/v1/games/${gameId}/rule-notes`, { content }),

	getMy: (gameId: string): Promise<MyRuleNote | null> =>
		api
			.get<MyRuleNote | undefined>(`/api/v1/games/${gameId}/rule-notes/my`)
			// 204 No Content resolves to undefined
			.then((note) => note ?? null)
			.catch((err: unknown) => {
				if (err instanceof ApiRequestError && err.status === 404) return null;
				throw err;
			}),

	deleteMy: (gameId: string): Promise<void> =>
		api.delete(`/api/v1/games/${gameId}/rule-notes/my`).then(() => undefined)
};
