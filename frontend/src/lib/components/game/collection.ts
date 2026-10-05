// Pure collection helpers shared by the library list, game detail and onboarding (unit-tested).
import type { UserGame } from '$lib/types';

/** Library tabs (SCREENS_AND_STATES section 5.1): the catalog plus three collection views. */
export type LibraryTab = 'all' | 'owned' | 'wishlist' | 'favorites';

export const LIBRARY_TABS: readonly LibraryTab[] = ['all', 'owned', 'wishlist', 'favorites'];

export function isLibraryTab(value: unknown): value is LibraryTab {
	return typeof value === 'string' && (LIBRARY_TABS as readonly string[]).includes(value);
}

/**
 * Entries shown on a collection tab, alphabetically, optionally narrowed by a title query
 * (case-insensitive, from 2 characters). The 'all' tab is the catalog, not the collection.
 */
export function filterCollection(items: readonly UserGame[], tab: LibraryTab, query = ''): UserGame[] {
	let result: UserGame[];
	switch (tab) {
		case 'owned':
			result = items.filter((ug) => ug.isOwned);
			break;
		case 'wishlist':
			result = items.filter((ug) => ug.isWishlisted);
			break;
		case 'favorites':
			result = items.filter((ug) => ug.isFavorited);
			break;
		default:
			result = [...items];
	}
	const q = query.trim().toLowerCase();
	if (q.length >= 2) {
		result = result.filter((ug) => (ug.game.title ?? '').toLowerCase().includes(q));
	}
	return result.sort((a, b) =>
		(a.game.title ?? '').localeCompare(b.game.title ?? '', undefined, { sensitivity: 'base' })
	);
}

/**
 * 1–10 rating to 0–5 stars (FEATURES_COMPLETE section 3.3: 1–2 = 1★ … 9–10 = 5★).
 * Null or out-of-range ratings show no stars.
 */
export function starsFromRating(rating: number | null | undefined): number {
	if (rating == null || !Number.isFinite(rating) || rating < 1) return 0;
	return Math.min(5, Math.ceil(Math.min(rating, 10) / 2));
}

/** Rating sent when the user taps star `stars` (1–5); tapping the current star clears it (0). */
export function ratingForStarTap(stars: number, currentRating: number | null | undefined): number {
	const clamped = Math.max(1, Math.min(5, Math.round(stars)));
	return starsFromRating(currentRating) === clamped ? 0 : clamped * 2;
}

/**
 * Replace (or drop, when the server removed it) the entry for `updated.game.id`, or add it.
 * Keeps local lists in sync with PUT /users/me/games/{id} responses.
 */
export function upsertEntry(items: readonly UserGame[], updated: UserGame): UserGame[] {
	const rest = items.filter((ug) => ug.game.id !== updated.game.id);
	return updated.id === null ? rest : [...rest, updated];
}
