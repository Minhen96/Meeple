import { ApiRequestError } from '$lib/api/client';

/** What the login form shows for a failed sign-in. */
export type LoginFailure =
	| { kind: 'deleted' }
	| { kind: 'unverified' }
	| { kind: 'locked' }
	| { kind: 'rateLimited'; retryAfterSeconds: number | null }
	| { kind: 'invalidCredentials' }
	| { kind: 'other'; code: string };

/** Classifies a login / reactivation error (FEATURES_COMPLETE section 1.2, SCREENS section 2.1). */
export function classifyLoginError(err: unknown): LoginFailure {
	if (!(err instanceof ApiRequestError)) return { kind: 'other', code: 'NETWORK_ERROR' };
	if (err.code === 'ACCOUNT_DELETED') return { kind: 'deleted' };
	if (err.code === 'EMAIL_NOT_VERIFIED') return { kind: 'unverified' };
	if (err.status === 429) {
		// The per-account lockout answers TOO_MANY_REQUESTS; the global limiter RATE_LIMIT_EXCEEDED
		return err.code === 'RATE_LIMIT_EXCEEDED'
			? { kind: 'rateLimited', retryAfterSeconds: err.retryAfterSeconds }
			: { kind: 'locked' };
	}
	if (err.status === 401) return { kind: 'invalidCredentials' };
	return { kind: 'other', code: err.code };
}
