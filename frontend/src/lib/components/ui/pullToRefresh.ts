/**
 * Pull-to-refresh gesture math (SCREENS_AND_STATES section 14.5), DOM-free for tests.
 * The finger's travel is damped so the indicator slows down as it is pulled further.
 */

/** Pull distance (px, after damping) that triggers a refresh on release. */
export const PULL_THRESHOLD = 64;
/** The indicator never moves further than this. */
export const PULL_MAX = 96;
const RESISTANCE = 0.5;

/** Damped pull distance for a finger travel of `delta` px (negative travel = no pull). */
export function pullDistance(delta: number): number {
	if (!Number.isFinite(delta) || delta <= 0) return 0;
	return Math.min(PULL_MAX, delta * RESISTANCE);
}

/** Whether releasing at `distance` should refresh. */
export function shouldRefresh(distance: number): boolean {
	return distance >= PULL_THRESHOLD;
}

/** Indicator progress 0..1 (drives the spinner's rotation / opacity). */
export function pullProgress(distance: number): number {
	return Math.min(1, Math.max(0, distance / PULL_THRESHOLD));
}

/**
 * Tailwind translate class for the indicator, in 8px steps (Tailwind only, no inline styles):
 * `translate-y-0`, `translate-y-2` … `translate-y-12`.
 */
export function indicatorOffsetClass(distance: number): string {
	// Full class names so Tailwind's scanner sees them
	const classes = [
		'translate-y-0',
		'translate-y-2',
		'translate-y-4',
		'translate-y-6',
		'translate-y-8',
		'translate-y-10',
		'translate-y-12'
	] as const;
	const step = Math.min(classes.length - 1, Math.floor(Math.max(0, distance) / 16));
	return classes[step];
}
