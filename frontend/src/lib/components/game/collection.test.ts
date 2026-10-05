import { describe, expect, it } from 'vitest';
import type { UserGame } from '$lib/types';
import {
	filterCollection,
	isLibraryTab,
	ratingForStarTap,
	starsFromRating,
	upsertEntry
} from './collection';

function entry(title: string, flags: Partial<UserGame> = {}): UserGame {
	return {
		id: `ug-${title}`,
		game: {
			id: `g-${title}`,
			bggId: title.length,
			title,
			thumbnailUrl: null,
			yearPublished: null,
			minPlayers: null,
			maxPlayers: null,
			playTime: null,
			minAge: null,
			rank: null,
			usersRated: null,
			bggRating: null
		},
		isOwned: false,
		isWishlisted: false,
		isFavorited: false,
		playCount: 0,
		personalRating: null,
		notes: null,
		addedAt: null,
		...flags
	};
}

const items = [
	entry('wingspan', { isOwned: true, isFavorited: true }),
	entry('Azul', { isWishlisted: true }),
	entry('catan', { isOwned: true }),
	entry('Played elsewhere', { playCount: 3 })
];

describe('filterCollection', () => {
	it('filters each tab by its flag and sorts alphabetically, case-insensitively', () => {
		expect(filterCollection(items, 'owned').map((u) => u.game.title)).toEqual(['catan', 'wingspan']);
		expect(filterCollection(items, 'wishlist').map((u) => u.game.title)).toEqual(['Azul']);
		expect(filterCollection(items, 'favorites').map((u) => u.game.title)).toEqual(['wingspan']);
		expect(filterCollection(items, 'all').map((u) => u.game.title)).toEqual([
			'Azul',
			'catan',
			'Played elsewhere',
			'wingspan'
		]);
	});

	it('narrows by title from two characters and ignores shorter queries', () => {
		expect(filterCollection(items, 'owned', 'WING').map((u) => u.game.title)).toEqual(['wingspan']);
		expect(filterCollection(items, 'owned', 'w')).toHaveLength(2);
		expect(filterCollection(items, 'wishlist', 'zz')).toEqual([]);
	});

	it('does not mutate its input', () => {
		const copy = [...items];
		filterCollection(items, 'all');
		expect(items).toEqual(copy);
	});
});

describe('star rating mapping', () => {
	it('maps 1–10 ratings to 1–5 stars per FEATURES 3.3', () => {
		expect([null, undefined, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12].map(starsFromRating)).toEqual([
			0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5
		]);
		expect(starsFromRating(Number.NaN)).toBe(0);
	});

	it('sends stars × 2, and 0 when tapping the current star', () => {
		expect(ratingForStarTap(4, null)).toBe(8);
		expect(ratingForStarTap(4, 7)).toBe(0);
		expect(ratingForStarTap(5, 8)).toBe(10);
		expect(ratingForStarTap(9, null)).toBe(10);
		expect(ratingForStarTap(0, null)).toBe(2);
	});
});

describe('upsertEntry', () => {
	it('replaces, adds, or drops a removed entry', () => {
		const updated = { ...items[1], isOwned: true };
		expect(upsertEntry(items, updated).find((u) => u.game.id === 'g-Azul')?.isOwned).toBe(true);

		const added = entry('Root', { isWishlisted: true });
		expect(upsertEntry(items, added)).toHaveLength(5);

		const removed = { ...items[1], id: null, isWishlisted: false };
		expect(upsertEntry(items, removed).some((u) => u.game.id === 'g-Azul')).toBe(false);
	});
});

describe('isLibraryTab', () => {
	it('accepts only known tabs', () => {
		expect(isLibraryTab('wishlist')).toBe(true);
		expect(isLibraryTab('played')).toBe(false);
		expect(isLibraryTab(3)).toBe(false);
	});
});
