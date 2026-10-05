import { describe, expect, it, vi } from 'vitest';

vi.mock('$app/environment', () => ({ browser: false }));
vi.mock('$app/navigation', () => ({ goto: vi.fn() }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));

const { ApiRequestError } = await import('$lib/api/client');
const { classifyLoginError } = await import('./loginErrors');

describe('classifyLoginError', () => {
	it('recognises a deleted account in its grace period', () => {
		expect(classifyLoginError(new ApiRequestError('ACCOUNT_DELETED', 'x', 403))).toEqual({ kind: 'deleted' });
	});

	it('separates the account lockout from the global rate limit', () => {
		expect(classifyLoginError(new ApiRequestError('TOO_MANY_REQUESTS', 'x', 429))).toEqual({ kind: 'locked' });
		expect(classifyLoginError(new ApiRequestError('RATE_LIMIT_EXCEEDED', 'x', 429, 42))).toEqual({
			kind: 'rateLimited',
			retryAfterSeconds: 42
		});
	});

	it('maps the remaining failures', () => {
		expect(classifyLoginError(new ApiRequestError('EMAIL_NOT_VERIFIED', 'x', 400))).toEqual({ kind: 'unverified' });
		expect(classifyLoginError(new ApiRequestError('UNAUTHORIZED', 'x', 401))).toEqual({ kind: 'invalidCredentials' });
		expect(classifyLoginError(new ApiRequestError('VALIDATION_ERROR', 'x', 400))).toEqual({
			kind: 'other',
			code: 'VALIDATION_ERROR'
		});
		expect(classifyLoginError(new Error('boom'))).toEqual({ kind: 'other', code: 'NETWORK_ERROR' });
	});
});
