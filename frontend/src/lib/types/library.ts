// Owned by WP4 (library, collection, AI). Re-exported from ./index.ts; import from '$lib/types'.

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
