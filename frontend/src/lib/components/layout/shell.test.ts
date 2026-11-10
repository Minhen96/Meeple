import { describe, expect, it } from 'vitest';
import { BOTTOM_NAV, CREATE_ACTIONS, SIDEBAR_NAV, badgeText, isNavActive } from './shell';

describe('app shell data', () => {
	it('marks Home active only on / and sections on their subtree', () => {
		expect(isNavActive('/', '/')).toBe(true);
		expect(isNavActive('/library', '/')).toBe(false);
		expect(isNavActive('/library', '/library')).toBe(true);
		expect(isNavActive('/library/abc', '/library')).toBe(true);
		expect(isNavActive('/libraryx', '/library')).toBe(false);
		expect(isNavActive('/events/create', '/events')).toBe(true);
		expect(isNavActive('/settings/profile', '/settings')).toBe(true);
	});

	it('formats the unread badge', () => {
		expect(badgeText(0)).toBeNull();
		expect(badgeText(-1)).toBeNull();
		expect(badgeText(7)).toBe('7');
		expect(badgeText(99)).toBe('99');
		expect(badgeText(100)).toBe('99+');
	});

	it('offers every bottom-nav tab in the sidebar, plus match, notifications and search', () => {
		const sidebar = SIDEBAR_NAV.map((i) => i.href);
		for (const tab of BOTTOM_NAV) expect(sidebar).toContain(tab.href);
		expect(sidebar).toEqual(['/', '/library', '/events', '/match', '/notifications', '/search', '/profile']);
		expect(SIDEBAR_NAV.filter((i) => i.badge === 'notifications').map((i) => i.href)).toEqual(['/notifications']);
	});

	it('has the four create actions in order', () => {
		expect(CREATE_ACTIONS.map((a) => a.href)).toEqual(['/posts/create', '/events/create', '/library', '/match']);
	});
});
