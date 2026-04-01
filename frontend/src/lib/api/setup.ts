import { api } from './client';

export interface SetupStatus {
	catalog: {
		imported: boolean;
		totalGames: number;
	};
	hydration: {
		started: boolean;
		hydrated: number;
		unhydrated: number;
		total: number;
		percentDone: number;
	};
	rulebooks: {
		pumpStarted: boolean;
		approved: number;
		target: number;
		percentDone: number;
	};
}

export const setupApi = {
	getStatus: () => api.get<SetupStatus>('/api/v1/admin/setup/status'),
	reset: () => api.post<{ message: string }>('/api/v1/admin/setup/reset')
};
