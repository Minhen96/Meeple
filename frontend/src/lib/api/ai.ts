import { api } from './client';
import type { AiAnswerResponse, ApiResponse, ConversationTurn } from '$lib/types';

export const aiApi = {
	askRules: (gameId: string, question: string, history: ConversationTurn[]) =>
		api
			.post<ApiResponse<AiAnswerResponse>>('/api/v1/ai/rules', {
				gameId,
				question,
				conversationHistory: history
			})
			.then((r) => r.data)
};
