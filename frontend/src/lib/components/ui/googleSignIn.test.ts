import { describe, expect, it } from 'vitest';
import { googleSignInConfigured } from './googleSignIn';

describe('googleSignInConfigured', () => {
	it('needs a non-blank client id', () => {
		expect(googleSignInConfigured('123.apps.googleusercontent.com')).toBe(true);
		expect(googleSignInConfigured('')).toBe(false);
		expect(googleSignInConfigured('   ')).toBe(false);
		expect(googleSignInConfigured(null)).toBe(false);
	});
});
