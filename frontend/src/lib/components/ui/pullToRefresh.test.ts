import { describe, expect, it } from 'vitest';
import {
	PULL_MAX,
	PULL_THRESHOLD,
	indicatorOffsetClass,
	pullDistance,
	pullProgress,
	shouldRefresh
} from './pullToRefresh';

describe('pull to refresh', () => {
	it('damps the pull and ignores upward moves', () => {
		expect(pullDistance(-20)).toBe(0);
		expect(pullDistance(Number.NaN)).toBe(0);
		expect(pullDistance(40)).toBe(20);
		expect(pullDistance(10_000)).toBe(PULL_MAX);
	});

	it('refreshes only past the threshold', () => {
		expect(shouldRefresh(PULL_THRESHOLD - 1)).toBe(false);
		expect(shouldRefresh(PULL_THRESHOLD)).toBe(true);
		expect(pullProgress(PULL_THRESHOLD / 2)).toBe(0.5);
		expect(pullProgress(PULL_MAX)).toBe(1);
		expect(pullProgress(-5)).toBe(0);
	});

	it('maps the distance to a static Tailwind class', () => {
		expect(indicatorOffsetClass(0)).toBe('translate-y-0');
		expect(indicatorOffsetClass(33)).toBe('translate-y-4');
		expect(indicatorOffsetClass(500)).toBe('translate-y-12');
		expect(indicatorOffsetClass(-3)).toBe('translate-y-0');
	});
});
