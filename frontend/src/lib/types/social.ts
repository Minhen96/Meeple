// Owned by WP3 (social, feed, posts). Re-exported from ./index.ts; import from '$lib/types'.

import type { User } from './account';
import type { UserSummary } from './common';
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
		/** The author soft-deleted their account: render "Deleted User". */
		deleted: boolean;
	};
	caption: string | null;
	location: string | null;
	playedAt: string | null;
	imageUrls: string[];
	game: GameSummary | null;
	eventId: string | null;
	taggedUsers: {
		id: string;
		username: string;
		displayName: string | null;
		avatarUrl: string | null;
	}[];
	likeCount: number;
	commentCount: number;
	likedByMe: boolean;
	isBookmarked: boolean;
	createdAt: string;
	/** Set when the author edited the post (within 48h); show "Edited". */
	editedAt: string | null;
}

// Maps to PostCommentResponse
export interface Comment {
	id: string;
	/**
	 * `deleted: true` (no name or avatar) when the author deleted their account; after the
	 * permanent delete the id is the all-zero placeholder, so never link it.
	 */
	author: UserSummary;
	/** Flat mirrors of `author`, kept for older clients. */
	authorId: string;
	authorUsername: string;
	authorDisplayName: string | null;
	authorAvatarUrl: string | null;
	body: string;
	createdAt: string;
	editedAt: string | null;
}

// ─── Feed ──────────────────────────────────────────────────────────────────
// GET /api/v1/feed?cursor=&limit= → CursorPage<FeedItem>

export type ActivityType = 'collection_add' | 'event_created' | 'event_joined';

/**
 * `data` is the recorded payload plus display fields filled in by the server:
 * gameId/gameName/gameThumbnailUrl and eventId/eventTitle/eventScheduledAt.
 */
export interface ActivityData {
	gameId?: string;
	gameName?: string;
	gameThumbnailUrl?: string | null;
	eventId?: string;
	eventTitle?: string;
	eventScheduledAt?: string;
	[key: string]: unknown;
}

export interface Activity {
	id: string;
	type: ActivityType;
	user: UserSummary;
	data: ActivityData;
}

export type FeedItem =
	| { kind: 'post'; createdAt: string; post: Post }
	| { kind: 'activity'; createdAt: string; activity: Activity };

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

/** Friendship status on search results (lower-case, docs/GAP_ANALYSIS.md 6.1). */
export type FriendshipStatus = 'none' | 'pending_sent' | 'pending_received' | 'friends';

export interface UserSummaryWithStatus {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	friendshipStatus: FriendshipStatus;
}

/** "People you may know": ranked by games in common with the viewer's collection. */
export interface SuggestedUser {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	sharedGames: number;
}

// ─── Search ────────────────────────────────────────────────────────────────
// GET /api/v1/search?q=&limit=&type=

export type SearchType = 'all' | 'games' | 'users' | 'events';

export interface EventSearchHit {
	id: string;
	title: string;
	scheduledAt: string;
	status: 'OPEN' | 'FULL' | 'COMPLETED' | 'CANCELLED';
	visibility: 'PUBLIC' | 'FRIENDS' | 'INVITE_ONLY';
	game: { id: string; title: string; thumbnailUrl: string | null } | null;
}

export interface SearchResults {
	games: GameSummary[];
	users: UserSummaryWithStatus[];
	events: EventSearchHit[];
}

// ─── Reports ───────────────────────────────────────────────────────────────

export type ReportTargetType = 'user' | 'post' | 'comment';
