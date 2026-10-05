import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const gotoMock = vi.hoisted(() => vi.fn());
vi.mock('$app/environment', () => ({ browser: true }));
vi.mock('$app/navigation', () => ({ goto: gotoMock }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));

const BASE = 'http://api.test';
vi.stubEnv('VITE_API_URL', BASE);

const { api, ApiRequestError, __resetRefreshStateForTests, parseRetryAfter, refreshesOn401 } =
	await import('./client');

function json(status: number, body: unknown = {}, headers: Record<string, string> = {}): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { 'Content-Type': 'application/json', ...headers }
	});
}

describe('rate limit and auth-path handling', () => {
	const fetchMock = vi.fn();

	beforeEach(() => {
		__resetRefreshStateForTests();
		fetchMock.mockReset();
		vi.stubGlobal('fetch', fetchMock);
	});

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('parses Retry-After seconds and dates', () => {
		const now = Date.parse('2026-10-05T12:00:00Z');
		expect(parseRetryAfter('30', now)).toBe(30);
		expect(parseRetryAfter(' 7 ', now)).toBe(7);
		expect(parseRetryAfter('Mon, 05 Oct 2026 12:00:45 GMT', now)).toBe(45);
		expect(parseRetryAfter('Mon, 05 Oct 2026 11:00:00 GMT', now)).toBe(0);
		expect(parseRetryAfter('soon', now)).toBeNull();
		expect(parseRetryAfter(null, now)).toBeNull();
	});

	it('exposes Retry-After on 429 errors', async () => {
		fetchMock.mockResolvedValue(
			json(429, { error: 'Too many', code: 'RATE_LIMIT_EXCEEDED' }, { 'Retry-After': '12' })
		);
		const error = await api.get('/api/v1/games').catch((e: unknown) => e);
		expect(error).toBeInstanceOf(ApiRequestError);
		expect((error as InstanceType<typeof ApiRequestError>).code).toBe('RATE_LIMIT_EXCEEDED');
		expect((error as InstanceType<typeof ApiRequestError>).retryAfterSeconds).toBe(12);
	});

	it('only 429s carry a retry delay', async () => {
		fetchMock.mockResolvedValue(json(400, { error: 'bad', code: 'VALIDATION_ERROR' }, { 'Retry-After': '5' }));
		const error = (await api.get('/api/v1/games').catch((e: unknown) => e)) as InstanceType<
			typeof ApiRequestError
		>;
		expect(error.retryAfterSeconds).toBeNull();
	});

	it('treats a 401 from session management as an expired session', () => {
		expect(refreshesOn401('/api/v1/users/me')).toBe(true);
		expect(refreshesOn401('/api/v1/auth/sessions')).toBe(true);
		expect(refreshesOn401('/api/v1/auth/sessions/abc')).toBe(true);
		expect(refreshesOn401('/api/v1/auth/sessions/revoke-others')).toBe(true);
		expect(refreshesOn401('/api/v1/auth/login')).toBe(false);
		expect(refreshesOn401('/api/v1/auth/reactivate')).toBe(false);
		expect(refreshesOn401('/api/v1/auth/sessionsx')).toBe(false);
	});

	it('refreshes and retries a 401 from GET /auth/sessions', async () => {
		fetchMock
			.mockResolvedValueOnce(json(401, { code: 'UNAUTHORIZED' }))
			.mockResolvedValueOnce(json(200, {}))
			.mockResolvedValueOnce(json(200, { data: [] }));
		await expect(api.get('/api/v1/auth/sessions')).resolves.toEqual([]);
		expect(fetchMock.mock.calls[1][0]).toBe(`${BASE}/api/v1/auth/refresh`);
	});

	it('sends a JSON body with DELETE when asked', async () => {
		fetchMock.mockResolvedValue(new Response(null, { status: 204 }));
		await api.deleteWithBody('/api/v1/users/me', { password: 'pw' });
		const init = fetchMock.mock.calls[0][1] ?? {};
		expect(init.method).toBe('DELETE');
		expect(init.body).toBe(JSON.stringify({ password: 'pw' }));
	});
});
