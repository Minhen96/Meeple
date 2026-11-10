/**
 * App shell data shared by the mobile bottom nav / create sheet and the tablet rail / desktop
 * sidebar (SCREENS_AND_STATES sections 1 and 16), so every width offers the same destinations.
 */
import type { MessageKey } from '$lib/i18n';

export interface NavItem {
	href: string;
	icon: string;
	label: MessageKey;
	/** Shows the unread-notifications badge. */
	badge?: 'notifications';
}

/** Bottom nav tabs (mobile), around the centre create button. */
export const BOTTOM_NAV: readonly NavItem[] = [
	{ href: '/', icon: 'home', label: 'common.nav.home' },
	{ href: '/library', icon: 'menu_book', label: 'common.nav.library' },
	{ href: '/events', icon: 'event', label: 'common.nav.events' },
	{ href: '/profile', icon: 'person', label: 'common.nav.profile' }
];

/** Rail / sidebar destinations (md and up). */
export const SIDEBAR_NAV: readonly NavItem[] = [
	{ href: '/', icon: 'home', label: 'common.nav.home' },
	{ href: '/library', icon: 'menu_book', label: 'common.nav.library' },
	{ href: '/events', icon: 'event', label: 'common.nav.events' },
	{ href: '/match', icon: 'group_add', label: 'common.nav.match' },
	{ href: '/notifications', icon: 'notifications', label: 'common.notifications', badge: 'notifications' },
	{ href: '/search', icon: 'search', label: 'common.search' },
	{ href: '/profile', icon: 'person', label: 'common.nav.profile' }
];

export interface CreateAction {
	icon: string;
	label: MessageKey;
	hint: MessageKey;
	href: string;
}

/** The "+" create options (PLAN section 3.8): Post / Event / Add Game / Find Match. */
export const CREATE_ACTIONS: readonly CreateAction[] = [
	{ icon: 'add_photo_alternate', label: 'common.create.post', hint: 'common.create.postHint', href: '/posts/create' },
	{ icon: 'event', label: 'common.create.event', hint: 'common.create.eventHint', href: '/events/create' },
	{ icon: 'library_add', label: 'common.create.game', hint: 'common.create.gameHint', href: '/library' },
	{ icon: 'group_add', label: 'common.create.match', hint: 'common.create.matchHint', href: '/match' }
];

/** Whether the nav item for `href` is the current section. Home matches only `/` itself. */
export function isNavActive(pathname: string, href: string): boolean {
	if (href === '/') return pathname === '/';
	return pathname === href || pathname.startsWith(`${href}/`);
}

/** Badge text for an unread count: hidden at 0, capped at "99+". */
export function badgeText(count: number): string | null {
	if (count <= 0) return null;
	return count > 99 ? '99+' : String(count);
}
