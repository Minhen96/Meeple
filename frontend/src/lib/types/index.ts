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

export interface User {
	id: string;
	username: string;
	email: string;
	displayName: string;
	avatarUrl: string | null;
	bio: string | null;
	location: string | null;
	onboardingCompleted: boolean;
	createdAt: string;
}

export interface UserProfile extends User {
	gamesOwned: number;
	sessionCount: number;
	friendCount: number;
	friendshipStatus: 'none' | 'pending_sent' | 'pending_received' | 'friends';
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

export interface Game {
	id: string;
	bggId: number;
	name: string;
	description: string | null;
	imageUrl: string | null;
	minPlayers: number | null;
	maxPlayers: number | null;
	playingTime: number | null;
	complexityWeight: number | null;
	yearPublished: number | null;
	bggRating: number | null;
	categories: string[];
	mechanics: string[];
	hasRulebook: boolean;
}

export interface UserGame {
	id: string;
	gameId: string;
	game: Game;
	isOwned: boolean;
	isWishlisted: boolean;
	isFavorited: boolean;
	personalRating: number | null;
	playCount: number;
	notes: string | null;
}

// ─── Event ─────────────────────────────────────────────────────────────────

export type EventVisibility = 'invite_only' | 'friends' | 'public';
export type EventStatus = 'open' | 'full' | 'completed' | 'cancelled';
export type RsvpStatus = 'invited' | 'accepted' | 'declined';

export interface Event {
	id: string;
	hostId: string;
	host: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>;
	gameId: string | null;
	game: Game | null;
	title: string;
	description: string | null;
	scheduledAt: string;
	location: string | null;
	maxPlayers: number;
	currentPlayers: number;
	visibility: EventVisibility;
	status: EventStatus;
	myRsvpStatus: RsvpStatus | null;
	createdAt: string;
}

export interface EventParticipant {
	userId: string;
	user: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>;
	status: RsvpStatus;
}

// ─── Post ──────────────────────────────────────────────────────────────────

export interface Post {
	id: string;
	authorId: string;
	author: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>;
	caption: string | null;
	images: PostImage[];
	gameId: string | null;
	game: Pick<Game, 'id' | 'name' | 'imageUrl'> | null;
	location: string | null;
	playedAt: string | null;
	likeCount: number;
	commentCount: number;
	isLiked: boolean;
	taggedUsers: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>[];
	createdAt: string;
}

export interface PostImage {
	id: string;
	url: string;
	order: number;
}

export interface Comment {
	id: string;
	authorId: string;
	author: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>;
	content: string;
	createdAt: string;
}

// ─── Friend Request ────────────────────────────────────────────────────────

export type FriendRequestStatus = 'pending' | 'accepted' | 'declined';

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

// ─── Match ─────────────────────────────────────────────────────────────────

export interface MatchRequest {
	id: string;
	userId: string;
	gameId: string;
	game: Pick<Game, 'id' | 'name' | 'imageUrl'>;
	availableFrom: string;
	availableUntil: string;
	status: 'active' | 'matched' | 'expired' | 'cancelled';
	createdAt: string;
}

export interface MatchGroup {
	id: string;
	gameId: string;
	game: Pick<Game, 'id' | 'name' | 'imageUrl'>;
	players: Pick<User, 'id' | 'username' | 'displayName' | 'avatarUrl'>[];
	createdAt: string;
}
