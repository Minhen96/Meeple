/**
 * Recent search queries for the search overlay, kept per user in localStorage. Storage can be
 * unavailable (private mode, blocked site data) or hold garbage, so every access is guarded and
 * the overlay simply shows no history in that case.
 */
export const MAX_RECENT_SEARCHES = 8;

export function recentSearchesKey(userId: string): string {
	return `meeple:recent-searches:${userId}`;
}

function storage(): Storage | null {
	try {
		return typeof localStorage === 'undefined' ? null : localStorage;
	} catch {
		return null;
	}
}

export function loadRecentSearches(userId: string): string[] {
	try {
		const raw = storage()?.getItem(recentSearchesKey(userId));
		if (!raw) return [];
		const parsed: unknown = JSON.parse(raw);
		return Array.isArray(parsed)
			? parsed
					.filter((q): q is string => typeof q === 'string' && q.trim() !== '')
					.slice(0, MAX_RECENT_SEARCHES)
			: [];
	} catch {
		return [];
	}
}

/** Moves `query` to the front (case-insensitive de-duplication) and returns the new list. */
export function addRecentSearch(list: string[], query: string): string[] {
	const q = query.trim();
	if (!q) return list;
	return [q, ...list.filter((item) => item.toLowerCase() !== q.toLowerCase())].slice(
		0,
		MAX_RECENT_SEARCHES
	);
}

export function saveRecentSearches(userId: string, list: string[]): void {
	try {
		const store = storage();
		if (!store) return;
		if (list.length === 0) store.removeItem(recentSearchesKey(userId));
		else
			store.setItem(recentSearchesKey(userId), JSON.stringify(list.slice(0, MAX_RECENT_SEARCHES)));
	} catch {
		// quota exceeded or storage blocked: history is a convenience, ignore
	}
}
