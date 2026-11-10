import { afterEach, describe, expect, it, vi } from 'vitest';
import {
	LG_QUERY,
	MD_QUERY,
	REDUCED_MOTION_QUERY,
	matchesMedia,
	motionDuration,
	prefersReducedMotion,
	watchMedia
} from './media';

type Listener = (event: MediaQueryListEvent) => void;

/** A fake matchMedia where the queries in `matching` match; returns the change listeners. */
function stubMatchMedia(matching: string[]) {
	const listeners = new Map<string, Listener[]>();
	const removed: string[] = [];
	const matchMedia = vi.fn((query: string) => ({
		matches: matching.includes(query),
		media: query,
		addEventListener: (_type: string, fn: Listener) => listeners.set(query, [...(listeners.get(query) ?? []), fn]),
		removeEventListener: () => removed.push(query)
	}));
	vi.stubGlobal('window', { matchMedia });
	return { listeners, removed };
}

afterEach(() => {
	vi.unstubAllGlobals();
});

describe('media helpers', () => {
	it('never match on the server', () => {
		expect(matchesMedia(MD_QUERY)).toBe(false);
		expect(prefersReducedMotion()).toBe(false);
		expect(motionDuration(250)).toBe(250);
		const seen: boolean[] = [];
		const stop = watchMedia(LG_QUERY, (m) => seen.push(m));
		expect(seen).toEqual([false]);
		expect(() => stop()).not.toThrow();
	});

	it('read matchMedia in the browser', () => {
		stubMatchMedia([MD_QUERY]);
		expect(matchesMedia(MD_QUERY)).toBe(true);
		expect(matchesMedia(LG_QUERY)).toBe(false);
	});

	it('collapse durations under prefers-reduced-motion', () => {
		stubMatchMedia([REDUCED_MOTION_QUERY]);
		expect(prefersReducedMotion()).toBe(true);
		expect(motionDuration(250)).toBe(0);
	});

	it('watch a query until unsubscribed', () => {
		const { listeners, removed } = stubMatchMedia([LG_QUERY]);
		const seen: boolean[] = [];
		const stop = watchMedia(LG_QUERY, (m) => seen.push(m));
		listeners.get(LG_QUERY)?.forEach((fn) => fn({ matches: false } as MediaQueryListEvent));
		expect(seen).toEqual([true, false]);
		stop();
		expect(removed).toEqual([LG_QUERY]);
	});
});
