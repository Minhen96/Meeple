// Owned by WP3 (social, feed, posts). Re-exported from ./index.ts; import from '$lib/types'.

import type { User } from './account';
import type { GameSummary } from './library';

// ─── Post ──────────────────────────────────────────────────────────────────
// Maps to PostResponse

export interface Post {
	id: string;
	author: {
		id: string;
		username: string;
		displayName: string | null;
		avatarUrl: string | null;
	};
	caption: string | null;
	location: string | null;
	playedAt: string | null;
	imageUrls: string[];
	game: GameSummary | null;
	taggedUsers: { id: string; username: string; avatarUrl: string | null }[];
	likeCount: number;
	commentCount: number;
	likedByMe: boolean;
	createdAt: string;
}

// Maps to PostCommentResponse
export interface Comment {
	id: string;
	authorId: string;
	authorUsername: string;
	authorAvatarUrl: string | null;
	body: string;
	createdAt: string;
}

// ─── Friend Request ────────────────────────────────────────────────────────

export type FriendRequestStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED';
export type FriendStatusValue =
	| 'NONE'
	| 'PENDING_SENT'
	| 'PENDING_RECEIVED'
	| 'FRIENDS'
	| 'BLOCKED';

export interface FriendRequest {
	id: string;
	sender: User;
	receiver: User;
	status: FriendRequestStatus;
	createdAt: string;
}

export interface FriendStatus {
	status: FriendStatusValue;
	requestId: string | null;
}
