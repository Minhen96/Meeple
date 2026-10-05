import { api, type ApiOptions } from './client';
import type {
	ActivityLog,
	BggImportStatus,
	CollectionFilter,
	GameDetail,
	GameFriend,
	GameReview,
	GameSearchResult,
	GameSessionsPage,
	GameSummary,
	LogPlayPayload,
	PlayLog,
	UserGame,
	UserStats
} from '$lib/types';

/** Partial update; `personalRating: 0` clears the rating. */
export interface UpdateCollectionPayload {
	isOwned?: boolean;
	isWishlisted?: boolean;
	isFavorited?: boolean;
	personalRating?: number;
	notes?: string | null;
}

/** Spring Page<GameSummaryResponse>, normalized by client.ts. */
export interface GamesPage {
	content: GameSummary[];
	number: number;
	last: boolean;
	totalPages: number;
	totalElements: number;
}

export const gamesApi = {
	search: async (query: string): Promise<GameSearchResult[]> => {
		const res = await api.get<GameSearchResult[]>(
			`/api/v1/games/search?q=${encodeURIComponent(query)}`
		);
		return res;
	},

	browse: async (params: {
		query?: string;
		genre?: string;
		minPlayers?: number;
		maxPlayers?: number;
		minPlaytime?: number; maxPlaytime?: number;
		minComplexity?: number; maxComplexity?: number;
		minRating?: number;
		page?: number;
		/**
		 * Spring Pageable sort, e.g. 'rank,asc', 'usersRated,desc' (popularity),
		 * 'yearPublished,desc', 'playTime,asc', or 'recommended' (personalized).
		 */
		sort?: string;
	}): Promise<GamesPage> => {
		const searchParams = new URLSearchParams();
		if (params.query) searchParams.set('q', params.query);
		if (params.genre) searchParams.set('genre', params.genre);
		if (params.minPlayers) searchParams.set('minPlayers', params.minPlayers.toString());
		if (params.maxPlayers) searchParams.set('maxPlayers', params.maxPlayers.toString());
		if (params.minPlaytime) searchParams.set('minPlaytime', params.minPlaytime.toString());
		if (params.maxPlaytime) searchParams.set('maxPlaytime', params.maxPlaytime.toString());
		if (params.minComplexity) searchParams.set('minComplexity', params.minComplexity.toString());
		if (params.maxComplexity) searchParams.set('maxComplexity', params.maxComplexity.toString());
		if (params.minRating) searchParams.set('minRating', params.minRating.toString());
		if (params.page !== undefined) searchParams.set('page', params.page.toString());
		if (params.sort) searchParams.set('sort', params.sort);
		const res = await api.get<GamesPage>(`/api/v1/games?${searchParams.toString()}`);
		return res;
	},

	getGame: async (id: string, opts?: ApiOptions): Promise<GameDetail> => {
		const res = await api.get<GameDetail>(`/api/v1/games/${id}`, opts);
		return res;
	},

	getMyCollection: async (opts?: ApiOptions, filter: CollectionFilter = 'all'): Promise<UserGame[]> => {
		const query = filter === 'all' ? '' : `?filter=${filter}`;
		const res = await api.get<UserGame[]>(`/api/v1/users/me/games${query}`, opts);
		return res;
	},

	updateCollection: async (gameId: string, payload: UpdateCollectionPayload): Promise<UserGame> => {
		const res = await api.put<UserGame>(`/api/v1/users/me/games/${gameId}`, payload);
		return res;
	},

	removeFromCollection: (gameId: string) =>
		api.delete<void>(`/api/v1/users/me/games/${gameId}`),

	/** Logs one play (defaults: now, no details). */
	logPlay: (gameId: string, payload: LogPlayPayload = {}): Promise<PlayLog> =>
		api.post<PlayLog>(`/api/v1/users/me/games/${gameId}/plays`, payload),

	deletePlay: (playId: string) => api.delete<void>(`/api/v1/users/me/plays/${playId}`),

	getPlays: async (gameId: string): Promise<PlayLog[]> => {
		const res = await api.get<PlayLog[]>(`/api/v1/users/me/games/${gameId}/plays`);
		return res;
	},

	getActivity: async (opts?: ApiOptions): Promise<ActivityLog[]> => {
		const res = await api.get<ActivityLog[]>('/api/v1/users/me/plays', opts);
		return res;
	},

	ensureGame: async (bggId: number): Promise<GameDetail> => {
		const res = await api.get<GameDetail>(`/api/v1/games/bgg/${bggId}`);
		return res;
	},

	getUserCollection: async (userId: string, opts?: ApiOptions): Promise<UserGame[]> => {
		const res = await api.get<UserGame[]>(`/api/v1/users/${userId}/games`, opts);
		return res;
	},

	getUserActivity: async (userId: string, opts?: ApiOptions): Promise<ActivityLog[]> => {
		const res = await api.get<ActivityLog[]>(`/api/v1/users/${userId}/plays`, opts);
		return res;
	},

	/** Profile stats bento; 404 when the user is blocked either way. */
	getUserStats: (userId: string, opts?: ApiOptions): Promise<UserStats> =>
		api.get<UserStats>(`/api/v1/users/${userId}/stats`, opts),

	getGameFriends: (gameId: string, opts?: ApiOptions): Promise<GameFriend[]> =>
		api.get<GameFriend[]>(`/api/v1/games/${gameId}/friends`, opts),

	getGameReviews: (gameId: string, opts?: ApiOptions): Promise<GameReview[]> =>
		api.get<GameReview[]>(`/api/v1/games/${gameId}/reviews`, opts),

	getGameSessions: (gameId: string, cursor?: string | null, limit = 10): Promise<GameSessionsPage> => {
		const params = new URLSearchParams({ limit: String(limit) });
		if (cursor) params.set('cursor', cursor);
		return api.get<GameSessionsPage>(`/api/v1/games/${gameId}/sessions?${params.toString()}`);
	},

	/** Starts a BoardGameGeek collection import (202); poll getBggImportStatus. */
	startBggImport: (bggUsername: string): Promise<BggImportStatus> =>
		api.post<BggImportStatus>('/api/v1/users/me/bgg-import', { bggUsername }),

	getBggImportStatus: (): Promise<BggImportStatus> =>
		api.get<BggImportStatus>('/api/v1/users/me/bgg-import/status')
};
