// Owned by WP4 (library, collection, AI). Re-exported from ./index.ts; import from '$lib/types'.

import type { CursorPage, UserSummary } from './common';
import type { Post } from './social';

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
	/** Average of the viewer's friends' ratings (1 decimal), null when no friend rated it. */
	friendAvgRating: number | null;
	friendRatingCount: number;
	/** Up to 5 friends who own the game. */
	ownedByFriends: UserSummary[];
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
	gameId: string;
	playedAt: string;
	notes: string | null;
	durationMinutes: number | null;
	playerCount: number | null;
	/** Set when a post that tagged the user recorded this play. */
	postId: string | null;
}

/** Body of POST /users/me/games/{gameId}/plays; every field is optional. */
export interface LogPlayPayload {
	playedAt?: string;
	notes?: string;
	durationMinutes?: number;
	playerCount?: number;
}

// ActivityLog maps to ActivityLogResponse — play log or event participation
export interface ActivityLog {
	id: string;
	type: 'play' | 'event' | 'post';
	game: GameSummary | null;
	playedAt: string;
	eventTitle?: string | null;
	eventId?: string | null;
	caption?: string | null;
	imageUrls?: string[];
	location?: string;
	scheduledAt?: string;
}

// UserGame maps to UserGameResponse. `id` is null when an update removed the entry
// (every flag cleared and nothing else left on it).
export interface UserGame {
	id: string | null;
	game: GameSummary;
	isOwned: boolean;
	isWishlisted: boolean;
	isFavorited: boolean;
	playCount: number;
	personalRating: number | null;
	notes: string | null;
	addedAt: string | null;
}

export type CollectionFilter = 'all' | 'owned' | 'wishlisted' | 'favorited';

// ─── Stats & friends ───────────────────────────────────────────────────────

/** GET /users/{id}/stats */
export interface UserStats {
	gamesOwned: number;
	sessions: number;
	friends: number;
	mostPlayedGame: { gameId: string; title: string; playCount: number } | null;
	favoriteCategory: string | null;
	mostPlayedWith: { userId: string; displayName: string; sharedSessions: number } | null;
	totalPlayMinutes: number;
}

/** GET /games/{id}/friends */
export interface GameFriend {
	user: UserSummary;
	playCount: number;
	personalRating: number | null;
	isOwned: boolean;
}

/** GET /games/{id}/reviews */
export interface GameReview {
	user: UserSummary;
	personalRating: number | null;
	notes: string | null;
	playCount: number;
}

/** GET /games/{id}/sessions */
export type GameSessionsPage = CursorPage<Post>;

// ─── BGG import ────────────────────────────────────────────────────────────

export type BggImportState = 'idle' | 'running' | 'done' | 'failed';
export type BggImportErrorCode = 'BGG_USER_NOT_FOUND' | 'BGG_API_UNAVAILABLE';

/** GET /users/me/bgg-import/status */
export interface BggImportStatus {
	status: BggImportState;
	total: number;
	processed: number;
	imported: number;
	skipped: number;
	failed: number;
	errorCode: BggImportErrorCode | null;
	/** Up to 5 imported games for the success screen. */
	preview: { gameId: string; title: string; thumbnailUrl: string | null }[];
}

// ─── Rulebook ──────────────────────────────────────────────────────────────

export interface RulebookStatus {
	hasRulebook: boolean;
	isIngesting: boolean;
	myStatus: string | null;
	myQueuePosition: number | null;
	hasHowToPlay: boolean;
}

/** Statuses the admin rulebook queue can be filtered by. */
export type RulebookQueueStatus = 'pending_review' | 'failed' | 'ingesting';

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
	setup?: string;
	components?: Array<{
		name: string;
		type?: string;
		description?: string;
		quantity?: number;
	}>;
	board?: { exists?: boolean; type?: string; description?: string };
	resources?: Array<{ name: string; usedFor?: string; gainedBy?: string }>;
	cardSystem?: {
		exists?: boolean;
		cardTypes?: Array<{ name: string; description: string }>;
		deckRules?: string;
		handRules?: string;
	};
	actions?: Array<{
		name: string;
		type?: string;
		cost?: string;
		effect?: string;
	}>;
	rules?: {
		coreRules?: string;
		specialRules?: Array<{ name: string; description: string }>;
		edgeCases?: string;
	};
	winCondition?: { type?: string; details?: string };
	scoring?: {
		exists?: boolean;
		methods?: Array<{ item: string; points: string }>;
	};
	endCondition?: { trigger?: string; notes?: string };
	roles?: {
		exists?: boolean;
		list?: Array<{ name: string; abilities: string; winCondition?: string }>;
	};
	variants?: Array<{ name: string; description: string }>;
	faq?: Array<{ question: string; answer: string }>;
	tips?: string[];
	raw?: string;
}

export type HowToPlayStatus = 'ready' | 'generating' | 'not_generated' | 'failed';

export interface HowToPlayApiResponse {
	status: HowToPlayStatus;
	data: HowToPlayContent | null;
	sourceMode: 'rulebook' | 'general' | null;
	disclaimer: string | null;
	rulebookUrl: string | null;
	approvedNotes: RuleNote[];
	progress: number | null;
	/** Set when status is 'failed'; a user-facing reason for the failed generation. */
	errorMessage: string | null;
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
