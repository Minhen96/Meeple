/**
 * Media-query helpers for the responsive shell (SCREENS_AND_STATES section 16). Safe on the
 * server and in tests without matchMedia: every query then reads as "not matching".
 */

/** Tablet and up: navigation rail instead of the bottom nav, sheets become dialogs. */
export const MD_QUERY = '(min-width: 768px)';
/** Desktop: full sidebar, toasts top-right. */
export const LG_QUERY = '(min-width: 1024px)';
export const REDUCED_MOTION_QUERY = '(prefers-reduced-motion: reduce)';

function mediaList(query: string): MediaQueryList | null {
	if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return null;
	return window.matchMedia(query);
}

/** Whether `query` matches right now (false on the server). */
export function matchesMedia(query: string): boolean {
	return mediaList(query)?.matches ?? false;
}

/** True when the user asked the OS for less motion. */
export function prefersReducedMotion(): boolean {
	return matchesMedia(REDUCED_MOTION_QUERY);
}

/** Transition duration that collapses to 0 under prefers-reduced-motion. */
export function motionDuration(ms: number): number {
	return prefersReducedMotion() ? 0 : ms;
}

/**
 * Call `onChange` with the current match and again whenever it changes.
 * Returns the unsubscribe function (a no-op without matchMedia).
 */
export function watchMedia(query: string, onChange: (matches: boolean) => void): () => void {
	const list = mediaList(query);
	if (!list) {
		onChange(false);
		return () => {};
	}
	const listener = (event: MediaQueryListEvent) => onChange(event.matches);
	onChange(list.matches);
	list.addEventListener('change', listener);
	return () => list.removeEventListener('change', listener);
}
