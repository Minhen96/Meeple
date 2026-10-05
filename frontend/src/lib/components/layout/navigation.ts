/**
 * Navigation helpers for the app shell (SCREENS_AND_STATES sections 1, 15.1, 15.4).
 * Pure functions plus a tiny amount of module state; no DOM access except where noted.
 */

/** Root route of each bottom-nav tab. */
export const TAB_ROOTS = ['/', '/library', '/events', '/profile'] as const;
export type TabRoot = (typeof TAB_ROOTS)[number];

/** The tab a path belongs to, or null for screens outside the tabs (settings, search…). */
export function tabRootOf(pathname: string): TabRoot | null {
	if (pathname === '/') return '/';
	for (const root of TAB_ROOTS) {
		if (root !== '/' && (pathname === root || pathname.startsWith(`${root}/`))) return root;
	}
	if (pathname.startsWith('/posts/')) return '/';
	return null;
}

/**
 * Logical parent of a screen, used by the back button when the user arrived by deep link
 * (no in-app history): event detail → events list, post → home, and so on.
 */
export function logicalParent(pathname: string): string {
	const path = pathname.length > 1 ? pathname.replace(/\/+$/, '') : pathname;
	if (path === '/' || path === '') return '/';
	if (path.startsWith('/settings/')) return '/settings';
	if (path === '/settings') return '/profile';
	if (path.startsWith('/profile/friends')) return '/profile';
	if (path.startsWith('/profile/')) return '/';
	if (path.startsWith('/events/')) return '/events';
	if (path.startsWith('/library/')) return '/library';
	if (path.startsWith('/admin')) return '/profile';
	return '/';
}

// ─── In-app history ─────────────────────────────────────────────────────────

let inAppNavigations = 0;

/** Record a completed navigation; `type` is SvelteKit's navigation type. */
export function recordNavigation(type: string): void {
	if (type !== 'enter') inAppNavigations += 1;
}

/** True once the user has navigated inside the app, so history.back() stays in the app. */
export function hasInAppHistory(): boolean {
	return inAppNavigations > 0;
}

/** Test hook. */
export function __resetNavigationForTests(): void {
	inAppNavigations = 0;
	scrollPositions.clear();
}

// ─── Per-tab scroll memory ─────────────────────────────────────────────────

const scrollPositions = new Map<TabRoot, number>();

/** Remember the scroll position of a tab's root screen when leaving it. */
export function rememberScroll(pathname: string, scrollY: number): void {
	const root = tabRootOf(pathname);
	if (root && root === pathname) scrollPositions.set(root, Math.max(0, scrollY));
}

/** Saved scroll position to restore when arriving at a tab root via the nav, or null. */
export function savedScroll(pathname: string): number | null {
	const root = tabRootOf(pathname);
	if (!root || root !== pathname) return null;
	return scrollPositions.get(root) ?? null;
}
