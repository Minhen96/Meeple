/**
 * Settings two-pane navigation (SCREENS_AND_STATES sections 11.1 and 16). On phones every settings
 * screen is its own page; from lg the menu stays in a left column and the selected screen fills
 * the right one.
 */

/** Strip a trailing slash so `/settings/` and `/settings` compare equal. */
function normalize(pathname: string): string {
	return pathname.length > 1 ? pathname.replace(/\/+$/, '') : pathname;
}

/** The settings menu itself (no sub-screen selected). */
export function isSettingsRoot(pathname: string): boolean {
	return normalize(pathname) === '/settings';
}

/**
 * Whether a menu row points at the screen being shown. Only in-app settings links can be active;
 * a link with a hash (Quiet hours → `/settings/notifications#quiet-hours`) never is, so the
 * notifications screen highlights a single row.
 */
export function isActiveSettingsHref(pathname: string, href: string | undefined): boolean {
	if (!href || !href.startsWith('/settings/') || href.includes('#')) return false;
	const path = normalize(pathname);
	const target = normalize(href);
	return path === target || path.startsWith(`${target}/`);
}
