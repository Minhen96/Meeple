import { describe, expect, it } from 'vitest';
import { browserTimezone, hasSeenWelcome, markWelcomeSeen, nextStepPath, stepNumber } from './onboarding';

function memoryStore() {
	const data = new Map<string, string>();
	return {
		getItem: (key: string) => data.get(key) ?? null,
		setItem: (key: string, value: string) => void data.set(key, value)
	};
}

describe('onboarding flow', () => {
	it('numbers steps 2–5 as dots 1–4', () => {
		expect(stepNumber('/onboarding/welcome')).toBeNull();
		expect(stepNumber('/onboarding/profile')).toBe(1);
		expect(stepNumber('/onboarding/find-friends')).toBe(3);
		expect(stepNumber('/onboarding/add-game')).toBe(4);
	});

	it('skips to the next step, then finishes', () => {
		expect(nextStepPath('/onboarding/welcome')).toBe('/onboarding/profile');
		expect(nextStepPath('/onboarding/profile')).toBe('/onboarding/bgg-import');
		expect(nextStepPath('/onboarding/find-friends')).toBe('/onboarding/add-game');
		expect(nextStepPath('/onboarding/add-game')).toBeNull();
	});

	it('remembers the welcome screen per user', () => {
		const store = memoryStore();
		expect(hasSeenWelcome('u1', store)).toBe(false);
		markWelcomeSeen('u1', store);
		expect(hasSeenWelcome('u1', store)).toBe(true);
		expect(hasSeenWelcome('u2', store)).toBe(false);
		expect(hasSeenWelcome('u1', null)).toBe(false);
	});

	it('survives broken storage', () => {
		const broken = {
			getItem: () => {
				throw new Error('blocked');
			},
			setItem: () => {
				throw new Error('blocked');
			}
		};
		expect(() => markWelcomeSeen('u1', broken)).not.toThrow();
		expect(hasSeenWelcome('u1', broken)).toBe(false);
	});

	it('reads the browser time zone', () => {
		expect(typeof browserTimezone()).toBe('string');
	});
});
