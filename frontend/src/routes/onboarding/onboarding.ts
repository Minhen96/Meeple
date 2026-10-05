/**
 * Onboarding flow (FEATURES_COMPLETE section 11, SCREENS_AND_STATES section 3): Welcome, then
 * steps 2–5 with progress dots. Pure helpers plus a per-user "welcome seen" marker so a user
 * who leaves mid-way resumes at step 2 instead of the welcome screen.
 */

/** Steps 2–5, in order (the dots). */
export const ONBOARDING_STEPS = ['profile', 'bgg-import', 'find-friends', 'add-game'] as const;
export type OnboardingStep = (typeof ONBOARDING_STEPS)[number];

/** 1-based position of the step shown at `pathname`, or null on the welcome screen. */
export function stepNumber(pathname: string): number | null {
	const index = ONBOARDING_STEPS.findIndex((step) => pathname.startsWith(`/onboarding/${step}`));
	return index < 0 ? null : index + 1;
}

/** Where "Skip" / "Continue" leads from `pathname`: the next step, or null after the last one. */
export function nextStepPath(pathname: string): string | null {
	const current = stepNumber(pathname);
	if (current === null) return `/onboarding/${ONBOARDING_STEPS[0]}`;
	const next = ONBOARDING_STEPS[current];
	return next ? `/onboarding/${next}` : null;
}

const WELCOME_SEEN_PREFIX = 'meeple.onboarding.welcomeSeen.';

type StorageLike = Pick<Storage, 'getItem' | 'setItem'>;

function storage(): StorageLike | null {
	try {
		return typeof localStorage === 'undefined' ? null : localStorage;
	} catch {
		return null;
	}
}

/** Remember that this user has seen the welcome screen. */
export function markWelcomeSeen(userId: string, store: StorageLike | null = storage()): void {
	try {
		store?.setItem(WELCOME_SEEN_PREFIX + userId, '1');
	} catch {
		// storage full or blocked: re-entry simply starts at the welcome screen
	}
}

/** True when this user already saw the welcome screen (re-entry starts at step 2). */
export function hasSeenWelcome(userId: string, store: StorageLike | null = storage()): boolean {
	try {
		return store?.getItem(WELCOME_SEEN_PREFIX + userId) === '1';
	} catch {
		return false;
	}
}

/** The browser's IANA time zone, or undefined when unavailable. */
export function browserTimezone(): string | undefined {
	try {
		return Intl.DateTimeFormat().resolvedOptions().timeZone || undefined;
	} catch {
		return undefined;
	}
}
