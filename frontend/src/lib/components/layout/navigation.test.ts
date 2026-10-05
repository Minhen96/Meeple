import { beforeEach, describe, expect, it } from 'vitest';
import {
	__resetNavigationForTests,
	hasInAppHistory,
	logicalParent,
	recordNavigation,
	rememberScroll,
	savedScroll,
	tabRootOf
} from './navigation';

describe('app navigation', () => {
	beforeEach(() => __resetNavigationForTests());

	it('maps paths to tabs', () => {
		expect(tabRootOf('/')).toBe('/');
		expect(tabRootOf('/library/abc')).toBe('/library');
		expect(tabRootOf('/events')).toBe('/events');
		expect(tabRootOf('/profile/friends')).toBe('/profile');
		expect(tabRootOf('/posts/1')).toBe('/');
		expect(tabRootOf('/settings')).toBeNull();
		expect(tabRootOf('/libraryx')).toBeNull();
	});

	it('finds the logical parent for deep links', () => {
		expect(logicalParent('/events/123')).toBe('/events');
		expect(logicalParent('/posts/456')).toBe('/');
		expect(logicalParent('/library/9/')).toBe('/library');
		expect(logicalParent('/settings/sessions')).toBe('/settings');
		expect(logicalParent('/settings')).toBe('/profile');
		expect(logicalParent('/profile/friends')).toBe('/profile');
		expect(logicalParent('/profile/u1')).toBe('/');
		expect(logicalParent('/admin/health')).toBe('/profile');
		expect(logicalParent('/notifications')).toBe('/');
		expect(logicalParent('/')).toBe('/');
	});

	it('knows whether back stays inside the app', () => {
		recordNavigation('enter');
		expect(hasInAppHistory()).toBe(false);
		recordNavigation('link');
		expect(hasInAppHistory()).toBe(true);
	});

	it('remembers scroll per tab root only', () => {
		rememberScroll('/library', 640);
		rememberScroll('/library/abc', 99);
		rememberScroll('/settings', 50);
		rememberScroll('/events', -10);
		expect(savedScroll('/library')).toBe(640);
		expect(savedScroll('/library/abc')).toBeNull();
		expect(savedScroll('/events')).toBe(0);
		expect(savedScroll('/profile')).toBeNull();
		expect(savedScroll('/settings')).toBeNull();
	});
});
