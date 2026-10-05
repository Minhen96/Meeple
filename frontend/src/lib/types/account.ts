// Owned by WP5 (account). Re-exported from ./index.ts; import from '$lib/types'.

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
