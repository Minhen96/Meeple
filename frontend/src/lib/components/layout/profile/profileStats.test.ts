import { describe, expect, it } from 'vitest';
import type { ProfileStats } from '$lib/types';
import { bentoStats } from './profileStats';

describe('bentoStats', () => {
	it('prefers the stats endpoint', () => {
		const stats: ProfileStats = {
			gamesOwned: 7,
			sessions: 30,
			friends: 4,
			mostPlayedGame: { gameId: 'g', title: 'Catan', playCount: 12 },
			favoriteCategory: 'Strategy',
			mostPlayedWith: { userId: 'u', displayName: 'Ana', sharedSessions: 5 },
			totalPlayMinutes: 900
		};
		expect(bentoStats(stats, [], 1)).toMatchObject({ gamesOwned: 7, sessions: 30, friends: 4, favoriteCategory: 'Strategy' });
	});

	it('falls back to the collection', () => {
		const collection = [
			{ isOwned: true, playCount: 3 },
			{ isOwned: false, playCount: 2 },
			{ isOwned: true, playCount: 0 }
		];
		expect(bentoStats(null, collection, 9)).toEqual({
			gamesOwned: 2,
			sessions: 5,
			friends: 9,
			mostPlayedGame: null,
			favoriteCategory: null,
			mostPlayedWith: null
		});
		expect(bentoStats(null, [], null).friends).toBeNull();
	});
});
