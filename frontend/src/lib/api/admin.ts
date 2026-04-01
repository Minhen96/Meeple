import { api } from './client';
import type { RulebookQueueItem, RulebookQueuePage } from '$lib/types';

export const adminApi = {
	getRulebookQueue: (status = 'pending_review', page = 0, size = 20): Promise<RulebookQueuePage> =>
		api.get<RulebookQueuePage>(
			`/api/v1/admin/rulebooks?status=${status}&page=${page}&size=${size}`
		),

	approveRulebook: (id: string): Promise<{ status: string }> =>
		api.post<{ status: string }>(`/api/v1/admin/rulebooks/${id}/approve`),

	rejectRulebook: (id: string, reason?: string): Promise<{ status: string }> =>
		api.post<{ status: string }>(`/api/v1/admin/rulebooks/${id}/reject`, { reason }),

	uploadRulebookForGame: (gameId: string, file: File): Promise<{ status: string; rulebookId: string }> => {
		const form = new FormData();
		form.append('file', file);
		return fetch(`${import.meta.env.VITE_API_URL}/api/v1/admin/games/${gameId}/rulebook`, {
			method: 'POST',
			credentials: 'include',
			body: form
		}).then((r) => r.json());
	}
};
