// ─── API Response Shapes ───────────────────────────────────────────────────

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

// ─── User ──────────────────────────────────────────────────────────────────
// Maps to UserProfileResponse

export interface User {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
	bio: string | null;
	location: string | null;
	onboardingCompleted: boolean;
	createdAt: string;
}

// ─── Auth ──────────────────────────────────────────────────────────────────

export interface LoginRequest {
	emailOrUsername: string;
	password: string;
}

export interface RegisterRequest {
	email: string;
	username: string;
	password: string;
}

// ─── Game ──────────────────────────────────────────────────────────────────
// GameSummary maps to GameSummaryResponse

export interface GameSummary {
	id: string;
	bggId: number;
	title: string;
	thumbnailUrl: string | null;
	yearPublished: number | null;
	minPlayers: number | null;
	maxPlayers: number | null;
	minPlaytime: number | null;
	maxPlaytime: number | null;
	complexityWeight: number | null;
	bggRating: number | null;
}

// GameDetail maps to GameDetailResponse
export interface GameDetail extends GameSummary {
	imageUrl: string | null;
	description: string | null;
}

// GameSearchResult maps to GameSearchResult
export interface GameSearchResult {
	id: string | null; // null if not yet cached in DB
	bggId: number;
	title: string;
	yearPublished: number | null;
	thumbnailUrl: string | null;
}

// UserGame maps to UserGameResponse
export interface UserGame {
	id: string;
	game: GameSummary;
	isOwned: boolean;
	isWishlisted: boolean;
	isFavorited: boolean;
	playCount: number;
	personalRating: number | null;
	notes: string | null;
}

// ─── Event ─────────────────────────────────────────────────────────────────
// Maps to EventResponse — backend returns uppercase enum names

export interface Event {
	id: string;
	host: { id: string; username: string; displayName: string | null; avatarUrl: string | null };
	game: GameSummary | null;
	title: string;
	description: string | null;
	location: string | null;
	scheduledAt: string;
	maxParticipants: number;
	participantCount: number;
	visibility: 'PUBLIC' | 'FRIENDS' | 'INVITE_ONLY';
	status: 'OPEN' | 'FULL' | 'COMPLETED' | 'CANCELLED';
	myRsvp: 'ACCEPTED' | 'DECLINED' | 'INVITED' | null;
	createdAt: string;
}

// ─── Post ──────────────────────────────────────────────────────────────────
// Maps to PostResponse

export interface Post {
	id: string;
	author: { id: string; username: string; displayName: string | null; avatarUrl: string | null };
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

export interface FriendRequest {
	id: string;
	senderId: string;
	sender: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>;
	receiverId: string;
	status: FriendRequestStatus;
	createdAt: string;
}

// ─── Notification ──────────────────────────────────────────────────────────

export type NotificationType =
	| 'event_invite'
	| 'event_reminder'
	| 'event_cancelled'
	| 'event_joined'
	| 'match_found'
	| 'friend_request'
	| 'friend_accepted'
	| 'post_like'
	| 'post_comment'
	| 'comment_mention'
	| 'post_tagged'
	| 'friend_activity'
	| 'system';

export interface Notification {
	id: string;
	recipientId: string;
	type: NotificationType;
	title: string;
	body: string;
	isRead: boolean;
	data: Record<string, string>;
	path: string | null;
	createdAt: string;
}
