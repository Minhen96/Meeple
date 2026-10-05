import { api, type ApiOptions } from './client';
import type { Comment, CursorPage, FeedItem, PaginatedResponse, Post } from '$lib/types';

export interface CreatePostPayload {
	caption?: string;
	imageKeys?: string[]; // R2 object keys from presigned upload
	gameId?: string;
	eventId?: string;
	location?: string;
	playedAt?: string; // ISO instant
	taggedUserIds?: string[];
}

/** PUT /posts/{id}: omitted fields are unchanged; '' clears caption/location. */
export interface UpdatePostPayload {
	caption?: string;
	location?: string;
	playedAt?: string;
	gameId?: string;
	clearGame?: boolean;
	taggedUserIds?: string[];
}

function cursorQuery(
	cursor: string | null | undefined,
	limit: number,
	extra?: Record<string, string>
): string {
	const params = new URLSearchParams({ limit: String(limit), ...extra });
	if (cursor) params.set('cursor', cursor);
	return params.toString();
}

export const postsApi = {
	/** Home feed: posts and activity items from friends and me, newest first. */
	getFeedPage: (
		cursor?: string | null,
		limit = 20,
		opts?: ApiOptions
	): Promise<CursorPage<FeedItem>> =>
		api.get<CursorPage<FeedItem>>(`/api/v1/feed?${cursorQuery(cursor, limit)}`, opts),

	getUserPosts: async (userId: string, page = 0, size = 20, opts?: ApiOptions): Promise<Post[]> => {
		const res = await api.get<PaginatedResponse<Post>>(
			`/api/v1/users/${userId}/posts?page=${page}&size=${size}`,
			opts
		);
		return res.data;
	},

	/** "View Memories": posts linked to an event. */
	getEventPosts: (
		eventId: string,
		cursor?: string | null,
		limit = 20,
		opts?: ApiOptions
	): Promise<CursorPage<Post>> =>
		api.get<CursorPage<Post>>(`/api/v1/posts?${cursorQuery(cursor, limit, { eventId })}`, opts),

	/** Posts the user is tagged in (profile "Tagged" tab). */
	getTaggedPosts: (
		userId: string,
		cursor?: string | null,
		limit = 30,
		opts?: ApiOptions
	): Promise<CursorPage<Post>> =>
		api.get<CursorPage<Post>>(
			`/api/v1/users/${userId}/tagged-posts?${cursorQuery(cursor, limit)}`,
			opts
		),

	getBookmarks: (
		cursor?: string | null,
		limit = 20,
		opts?: ApiOptions
	): Promise<CursorPage<Post>> =>
		api.get<CursorPage<Post>>(`/api/v1/users/me/bookmarks?${cursorQuery(cursor, limit)}`, opts),

	getPost: (id: string, opts?: ApiOptions): Promise<Post> =>
		api.get<Post>(`/api/v1/posts/${id}`, opts),

	createPost: (payload: CreatePostPayload): Promise<Post> =>
		api.post<Post>('/api/v1/posts', payload),

	updatePost: (id: string, payload: UpdatePostPayload): Promise<Post> =>
		api.put<Post>(`/api/v1/posts/${id}`, payload),

	deletePost: (id: string) => api.delete<void>(`/api/v1/posts/${id}`),

	// All return 204 void — callers do optimistic updates
	likePost: (id: string) => api.post<void>(`/api/v1/posts/${id}/like`),
	unlikePost: (id: string) => api.delete<void>(`/api/v1/posts/${id}/like`),
	bookmarkPost: (id: string) => api.post<void>(`/api/v1/posts/${id}/bookmark`),
	unbookmarkPost: (id: string) => api.delete<void>(`/api/v1/posts/${id}/bookmark`),

	/** Comments oldest first; pass the previous page's `nextCursor` for the next one. */
	getComments: (
		postId: string,
		cursor?: string | null,
		limit = 20,
		opts?: ApiOptions
	): Promise<CursorPage<Comment>> =>
		api.get<CursorPage<Comment>>(
			`/api/v1/posts/${postId}/comments?${cursorQuery(cursor, limit)}`,
			opts
		),

	addComment: (postId: string, body: string): Promise<Comment> =>
		api.post<Comment>(`/api/v1/posts/${postId}/comments`, { body }),

	/** Comment author only, within 24h. */
	updateComment: (postId: string, commentId: string, body: string): Promise<Comment> =>
		api.put<Comment>(`/api/v1/posts/${postId}/comments/${commentId}`, { body }),

	/** Comment author or post author. */
	deleteComment: (postId: string, commentId: string) =>
		api.delete<void>(`/api/v1/posts/${postId}/comments/${commentId}`)
};
