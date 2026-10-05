// Owned by WP5 (account). Re-exported from ./index.ts; import from '$lib/types'.

// ─── User ──────────────────────────────────────────────────────────────────
// Maps to UserProfileResponse. Fields marked "self only" are null for other users.

export type PreferredLanguage = 'en' | 'zh-CN';

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
	isVerified?: boolean;
	/** Self only. */
	email?: string | null;
	/** Self only. */
	preferredLanguage?: PreferredLanguage | null;
	/** Self only. IANA time zone. */
	timezone?: string | null;
	/** Self only. */
	bggUsername?: string | null;
	/** Self only. When the username may next change; null when it may change now. */
	usernameChangeAvailableAt?: string | null;
	/** Self only. False for Google-only accounts. */
	hasPassword?: boolean | null;
	/** Self only. */
	googleLinked?: boolean | null;
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

/** POST /auth/reactivate: password accounts send credentials, Google accounts an ID token. */
export type ReactivateRequest =
	| { emailOrUsername: string; password: string }
	| { googleIdToken: string };

/** DELETE /users/me body (C11). */
export type DeleteAccountRequest =
	| { password: string }
	| { googleIdToken: string }
	| { confirm: 'DELETE' };

// ─── Sessions ──────────────────────────────────────────────────────────────

/** GET /auth/sessions item. */
export interface SessionInfo {
	id: string;
	deviceInfo: string | null;
	createdAt: string;
	lastUsedAt: string;
	current: boolean;
}

// ─── Data export ───────────────────────────────────────────────────────────

export type DataExportStatus = 'PENDING' | 'RUNNING' | 'COMPLETED' | 'FAILED';

export interface DataExport {
	id: string;
	status: DataExportStatus;
	createdAt: string;
	completedAt: string | null;
}

// ─── Profile stats ─────────────────────────────────────────────────────────
// GET /users/{id}/stats (served by the library package, docs/GAP_ANALYSIS.md section 6.1).

export interface ProfileStats {
	gamesOwned: number;
	sessions: number;
	friends: number;
	mostPlayedGame: { gameId: string; title: string; playCount: number } | null;
	favoriteCategory: string | null;
	mostPlayedWith: { userId: string; displayName: string; sharedSessions: number } | null;
	totalPlayMinutes: number;
}
