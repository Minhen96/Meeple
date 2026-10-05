import type { ProfileStats, UserGame } from '$lib/types';

/** The three bento numbers plus the optional highlights. */
export interface BentoStats {
	gamesOwned: number;
	sessions: number;
	friends: number | null;
	mostPlayedGame: ProfileStats['mostPlayedGame'];
	favoriteCategory: string | null;
	mostPlayedWith: ProfileStats['mostPlayedWith'];
}

/**
 * Bento numbers from GET /users/{id}/stats when available; otherwise (stats endpoint not
 * deployed, or it failed) a best-effort fallback computed from the visible collection.
 */
export function bentoStats(
	stats: ProfileStats | null,
	collection: Pick<UserGame, 'isOwned' | 'playCount'>[],
	friendCount: number | null
): BentoStats {
	if (stats) {
		return {
			gamesOwned: stats.gamesOwned,
			sessions: stats.sessions,
			friends: stats.friends,
			mostPlayedGame: stats.mostPlayedGame,
			favoriteCategory: stats.favoriteCategory,
			mostPlayedWith: stats.mostPlayedWith
		};
	}
	return {
		gamesOwned: collection.filter((g) => g.isOwned).length,
		sessions: collection.reduce((sum, g) => sum + (g.playCount || 0), 0),
		friends: friendCount,
		mostPlayedGame: null,
		favoriteCategory: null,
		mostPlayedWith: null
	};
}
