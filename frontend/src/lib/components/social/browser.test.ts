// @vitest-environment jsdom
// Browser-bound helpers: scroll-depth watcher, default share environment, default storages.
import { afterEach, describe, expect, it, vi } from 'vitest';
import { watchScrollDepth } from './cursorPager';
import { shareLink } from './share';
import { loadRecentSearches, recentSearchesKey } from './recentSearches';
import { hasSeenWelcome, markWelcomeSeen } from '../../../routes/onboarding/onboarding';

afterEach(() => {
	vi.unstubAllGlobals();
	localStorage.clear();
});

function setScroll(scrollY: number, innerHeight: number, scrollHeight: number) {
	Object.defineProperty(window, 'scrollY', { value: scrollY, configurable: true });
	Object.defineProperty(window, 'innerHeight', { value: innerHeight, configurable: true });
	Object.defineProperty(document.documentElement, 'scrollHeight', { value: scrollHeight, configurable: true });
}

describe('watchScrollDepth', () => {
	it('fires immediately for short pages and on scroll/resize past the depth, until cleaned up', () => {
		const onReach = vi.fn();
		setScroll(0, 800, 500);
		const stop = watchScrollDepth(onReach);
		expect(onReach).toHaveBeenCalledTimes(1);

		setScroll(0, 800, 4000);
		window.dispatchEvent(new Event('scroll'));
		expect(onReach).toHaveBeenCalledTimes(1);

		setScroll(2600, 800, 4000); // (2600+800)/4000 = 0.85
		window.dispatchEvent(new Event('scroll'));
		window.dispatchEvent(new Event('resize'));
		expect(onReach).toHaveBeenCalledTimes(3);

		stop();
		window.dispatchEvent(new Event('scroll'));
		expect(onReach).toHaveBeenCalledTimes(3);
	});
});

describe('shareLink with the real navigator', () => {
	it('uses navigator.share when available', async () => {
		const share = vi.fn(async () => {});
		vi.stubGlobal('navigator', { share });
		await expect(shareLink('https://x/posts/1', 'Post')).resolves.toBe('shared');
		expect(share).toHaveBeenCalledWith({ url: 'https://x/posts/1', title: 'Post' });
	});

	it('falls back to the clipboard', async () => {
		const writeText = vi.fn(async () => {});
		vi.stubGlobal('navigator', { clipboard: { writeText } });
		await expect(shareLink('https://x/posts/1', 'Post')).resolves.toBe('copied');
		expect(writeText).toHaveBeenCalledWith('https://x/posts/1');
	});

	it('fails without either API', async () => {
		vi.stubGlobal('navigator', {});
		await expect(shareLink('u', 't')).resolves.toBe('failed');
	});
});

describe('default localStorage-backed helpers', () => {
	it('recent searches read from localStorage by default', () => {
		localStorage.setItem(recentSearchesKey('u1'), JSON.stringify(['catan', '', 'azul']));
		expect(loadRecentSearches('u1')).toEqual(['catan', 'azul']);
	});

	it('welcome-seen flag round-trips through localStorage', () => {
		expect(hasSeenWelcome('u1')).toBe(false);
		markWelcomeSeen('u1');
		expect(hasSeenWelcome('u1')).toBe(true);
	});
});
