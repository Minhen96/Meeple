// Owned by Step 0 (shared; change only through a docs/GAP_ANALYSIS.md section 6 contract). Re-exported from ./index.ts; import from '$lib/types'.

export interface ApiResponse<T> {
	data: T;
}

export interface ApiError {
	error: string;
	code: string;
}

export interface PaginatedResponse<T> {
	data: T[];
	meta: {
		page: number;
		limit: number;
		total: number;
		hasMore: boolean;
	};
}

/** Cursor page for live lists (feed, notifications, bookmarks): `?cursor=&limit=`. */
export interface CursorPage<T> {
	items: T[];
	nextCursor: string | null;
	hasMore: boolean;
}

/** Shared user reference shape everywhere (docs/GAP_ANALYSIS.md section 6.1). */
export interface UserSummary {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	deleted: boolean;
}
