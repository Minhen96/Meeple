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
	isAdmin: boolean;
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
	playTime: number | null;
	minAge: number | null;
	rank: number | null;
	usersRated: number | null;
	bggRating: number | null;
}

// GameDetail maps to GameDetailResponse
export interface GameDetail extends GameSummary {
	imageUrl: string | null;
	description: string | null;
	complexityWeight: number | null;
	ownedCount: number | null;
	gameType: string | null;
	bggUrl: string | null;
	categories: string[] | null;
	mechanics: string[] | null;
	families: string[] | null;
	designers: string[] | null;
	publishers: string[] | null;
	honors: string[] | null;
	expansions: string[] | null;
	hasRulebook: boolean;
}

// GameSearchResult maps to GameSearchResult
export interface GameSearchResult {
	id: string | null; // null if not yet cached in DB
	bggId: number;
	title: string;
	yearPublished: number | null;
	thumbnailUrl: string | null;
	translatedFrom: string | null; // e.g. if the user searched for '卡坦岛'
}

// PlayLog maps to PlayLogResponse
export interface PlayLog {
	id: string;
	playedAt: string;
}

// ActivityLog maps to ActivityLogResponse — play log with game context
export interface ActivityLog {
	id: string;
	game: GameSummary;
	playedAt: string;
}

// UserGame maps to UserGameResponse
export interface UserGame {
	id: string;
	game: GameSummary;
	isOwned: boolean;
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

// ─── Match ─────────────────────────────────────────────────────────────────

export interface MatchRequest {
	id: string;
	game: GameSummary;
	availableFrom: string | null;
	availableTo: string | null;
	status: 'ACTIVE' | 'MATCHED' | 'CANCELLED' | 'EXPIRED';
	createdAt: string;
}

export interface MatchGroup {
	id: string;
	game: GameSummary;
	overlapStart: string | null;
	overlapEnd: string | null;
	status: 'PENDING' | 'ACCEPTED' | 'DISMISSED' | 'EXPIRED';
	members: User[];
	createdAt: string;
}

// ─── Friend Request ────────────────────────────────────────────────────────

export type FriendRequestStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED';
export type FriendStatusValue = 'NONE' | 'PENDING_SENT' | 'PENDING_RECEIVED' | 'FRIENDS' | 'BLOCKED';

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

// ─── Rulebook ──────────────────────────────────────────────────────────────

export interface RulebookStatus {
	hasRulebook: boolean;
	isIngesting: boolean;
	myStatus: string | null;
	myQueuePosition: number | null;
	hasHowToPlay: boolean;
}

export interface RulebookQueueItem {
	id: string;
	gameId: string;
	gameName: string;
	source: string;
	fileUrl: string | null;
	uploaderUsername: string | null;
	queuePosition: number | null;
	createdAt: string;
}

export interface RulebookQueuePage {
	content: RulebookQueueItem[];
	totalElements: number;
	totalPages: number;
	number: number;
	last: boolean;
}

// ─── AI ────────────────────────────────────────────────────────────────────

export interface ConversationTurn {
	question: string;
	answer: string;
}

export interface AiAnswerResponse {
	answer: string;
	sourceMode: 'rulebook' | 'general';
	disclaimer: string;
	cached: boolean;
}

export interface HowToPlayContent {
	overview?: string;
	objective?: string;
	gameStructure?: {
		mode?: string;
		phases?: Array<{ name: string; description: string; actions?: string[] }>;
		turnOrder?: string;
	};
	components?: Array<{ name: string; type?: string; description?: string; quantity?: number }>;
	board?: { exists?: boolean; type?: string; description?: string };
	resources?: Array<{ name: string; usedFor?: string; gainedBy?: string }>;
	cardSystem?: {
		exists?: boolean;
		cardTypes?: Array<{ name: string; description: string }>;
		deckRules?: string;
		handRules?: string;
	};
	actions?: Array<{ name: string; type?: string; cost?: string; effect?: string }>;
	rules?: {
		coreRules?: string;
		specialRules?: Array<{ name: string; description: string }>;
		edgeCases?: string;
	};
	winCondition?: { type?: string; details?: string };
	scoring?: { exists?: boolean; methods?: Array<{ item: string; points: string }> };
	endCondition?: { trigger?: string; notes?: string };
	roles?: { exists?: boolean; list?: Array<{ name: string; abilities: string; winCondition?: string }> };
	variants?: Array<{ name: string; description: string }>;
	faq?: Array<{ question: string; answer: string }>;
	tips?: string[];
	raw?: string;
}

export interface HowToPlayApiResponse {
	status: 'ready' | 'generating';
	data: HowToPlayContent | null;
	sourceMode: 'rulebook' | 'general' | null;
	disclaimer: string | null;
	rulebookUrl: string | null;
	approvedNotes: RuleNote[];
}

export interface RuleNote {
	id: string;
	content: string;
	submittedByUsername: string;
	createdAt: string;
}

export interface MyRuleNote {
	id: string;
	content: string;
	status: 'pending' | 'approved' | 'rejected';
	rejectReason: string | null;
	updatedAt: string;
}

export interface RuleNoteQueueItem {
	id: string;
	gameId: string;
	gameName: string;
	content: string;
	submittedByUsername: string;
	createdAt: string;
}

export interface RuleNoteQueuePage {
	content: RuleNoteQueueItem[];
	number: number;
	last: boolean;
	totalElements: number;
}

// ─── Notification ──────────────────────────────────────────────────────────

export type NotificationType =
	| 'EVENT_INVITE'
	| 'EVENT_RSVP'
	| 'POST_LIKE'
	| 'POST_COMMENT'
	| 'FRIEND_REQUEST'
	| 'FRIEND_ACCEPTED'
	| 'MATCH_FOUND';

export interface Notification {
	id: string;
	type: NotificationType;
	actorId: string | null;
	referenceId: string | null;
	referenceType: string | null;
	read: boolean;
	createdAt: string;
}
