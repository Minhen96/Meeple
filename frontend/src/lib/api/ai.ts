import { api } from './client';
import type { AiAnswerResponse, ConversationTurn } from '$lib/types';

export const aiApi = {
	askRules: (gameId: string, question: string, history: ConversationTurn[] = []): Promise<AiAnswerResponse> =>
		api.post<AiAnswerResponse>('/api/v1/ai/rules', {
			gameId,
			question,
			conversationHistory: history
		})
};
