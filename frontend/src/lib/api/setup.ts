import { api } from './client';
import type { ApiResponse } from '$lib/types';

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
		running: boolean;
		stopRequested: boolean;
	};
	rulebooks: {
		pumpStarted: boolean;
		approved: number;
		ingesting: number;
		target: number;
		percentDone: number;
		running: boolean;
		stopRequested: boolean;
	};
}

export interface CsvCheckResult {
	url: string;
	accessible: boolean;
	pass: boolean;
	httpStatus?: number;
	contentType?: string;
	sizeBytes?: number;
	sizeMb?: string;
	verdict: string;
	error?: string;
}

export const setupApi = {
	getStatus: () =>
		api.get<SetupStatus>('/api/v1/admin/setup/status'),
	checkCsv: () =>
		api.get<CsvCheckResult>('/api/v1/admin/setup/check-csv'),
	start: (step: 'import' | 'hydrate' | 'rulebooks') =>
		api.post<ApiResponse<{ message: string }>>(`/api/v1/admin/setup/start/${step}`),
	stop: (step: 'hydrate' | 'rulebooks') =>
		api.post<ApiResponse<{ message: string }>>(`/api/v1/admin/setup/stop/${step}`),
	reset: () => api.post<ApiResponse<{ message: string }>>('/api/v1/admin/setup/reset')
};
