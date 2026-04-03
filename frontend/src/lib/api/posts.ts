import { api } from './client';
import type { ApiResponse, Comment, Post } from '$lib/types';

// Backend returns PageResponse<T> = { data: T[], meta: { page, limit, total, hasMore } }
interface PagedResponse<T> {
	data: T[];
	meta: { page: number; limit: number; total: number; hasMore: boolean };
}

export interface CreatePostPayload {
	caption?: string;
	imageKeys?: string[]; // R2 object keys from presigned upload
	gameId?: string;
	eventId?: string;
	location?: string;
	playedAt?: string; // ISO instant
	taggedUserIds?: string[];
}

export const postsApi = {
	// Feed is at /api/v1/feed (not /api/v1/posts)
	getFeed: async (page = 0, size = 20): Promise<Post[]> => {
		const res = await api.get<PagedResponse<Post>>(`/api/v1/feed?page=${page}&size=${size}`);
		return res.data;
	},

	getUserPosts: async (userId: string, page = 0, size = 20): Promise<Post[]> => {
		const res = await api.get<PagedResponse<Post>>(
			`/api/v1/users/${userId}/posts?page=${page}&size=${size}`
		);
		return res.data;
	},

	getPost: async (id: string): Promise<Post> => {
		const res = await api.get<Post>(`/api/v1/posts/${id}`);
		return res;
	},

	createPost: async (payload: CreatePostPayload): Promise<Post> => {
		const res = await api.post<Post>('/api/v1/posts', payload);
		return res;
	},

	deletePost: (id: string) => api.delete<void>(`/api/v1/posts/${id}`),

	// Both return 204 void — callers must do optimistic updates
	likePost: (id: string) => api.post<void>(`/api/v1/posts/${id}/like`),
	unlikePost: (id: string) => api.delete<void>(`/api/v1/posts/${id}/like`),

	getComments: async (postId: string, page = 0, size = 20): Promise<Comment[]> => {
		const res = await api.get<Comment[]>(
			`/api/v1/posts/${postId}/comments?page=${page}&size=${size}`
		);
		return res;
	},

	addComment: async (postId: string, body: string): Promise<Comment> => {
		const res = await api.post<Comment>(`/api/v1/posts/${postId}/comments`, { body });
		return res;
	}
};
