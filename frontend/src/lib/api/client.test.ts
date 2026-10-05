import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const env = vi.hoisted(() => ({ browser: true }));
const gotoMock = vi.hoisted(() => vi.fn());
const clearSessionMock = vi.hoisted(() => vi.fn());

vi.mock('$app/environment', () => ({
	get browser() {
		return env.browser;
	}
}));
vi.mock('$app/navigation', () => ({ goto: gotoMock }));
vi.mock('$lib/session', () => ({ clearClientSession: clearSessionMock }));

const BASE = 'http://api.test';
vi.stubEnv('VITE_API_URL', BASE);

const { api, ApiRequestError, __resetRefreshStateForTests, ensureSession, onSessionRefreshed } =
	await import('./client');

function json(status: number, body: unknown = {}): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { 'Content-Type': 'application/json' }
	});
}

type FetchArgs = [input: RequestInfo | URL, init?: RequestInit];

function urlOf(input: RequestInfo | URL): string {
	if (typeof input === 'string') return input;
	return input instanceof URL ? input.href : input.url;
}

function initOf(call: FetchArgs): RequestInit {
	return call[1] ?? {};
}

function headersOf(call: FetchArgs): Headers {
	return new Headers(initOf(call).headers);
}

beforeEach(() => {
	env.browser = true;
	gotoMock.mockReset();
	clearSessionMock.mockReset();
	__resetRefreshStateForTests();
	vi.stubGlobal('navigator', {});
});

afterEach(() => {
	vi.unstubAllGlobals();
});

describe('header merging', () => {
	it('keeps computed headers and credentials when the caller passes headers', async () => {
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async () => json(200, { ok: true }));

		await api.post('/api/v1/x', { a: 1 }, { fetch: fetchMock, headers: { 'X-Trace': 'abc' } });

		const call = fetchMock.mock.calls[0];
		const headers = headersOf(call);
		expect(urlOf(call[0])).toBe(`${BASE}/api/v1/x`);
		expect(initOf(call).credentials).toBe('include');
		expect(initOf(call).method).toBe('POST');
		expect(initOf(call).body).toBe('{"a":1}');
		expect(headers.get('content-type')).toBe('application/json');
		expect(headers.get('x-trace')).toBe('abc');
	});

	it('lets caller headers override computed ones', async () => {
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async () => json(200));

		await api.put('/api/v1/x', 'raw', {
			fetch: fetchMock,
			headers: new Headers({ 'Content-Type': 'text/plain' })
		});

		expect(headersOf(fetchMock.mock.calls[0]).get('content-type')).toBe('text/plain');
	});

	it('does not set Content-Type for FormData bodies', async () => {
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async () => json(200));
		const form = new FormData();
		form.append('file', new Blob(['x']), 'a.pdf');

		await api.post('/api/v1/upload', form, { fetch: fetchMock });

		const call = fetchMock.mock.calls[0];
		expect(initOf(call).body).toBe(form);
		expect(headersOf(call).has('content-type')).toBe(false);
	});

	it('unwraps generic { data } wrappers but not paginated ones', async () => {
		const fetchMock = vi
			.fn<FetchArgs, Promise<Response>>()
			.mockResolvedValueOnce(json(200, { data: { id: 'u1' } }))
			.mockResolvedValueOnce(json(200, { data: [1], meta: { total: 1 } }));

		expect(await api.get('/a', { fetch: fetchMock })).toEqual({ id: 'u1' });
		expect(await api.get('/b', { fetch: fetchMock })).toEqual({ data: [1], meta: { total: 1 } });
	});

	it('throws ApiRequestError with backend code/message', async () => {
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async () =>
			json(429, { code: 'RATE_LIMITED', error: 'Slow down' })
		);

		await expect(api.get('/a', { fetch: fetchMock })).rejects.toMatchObject({
			code: 'RATE_LIMITED',
			message: 'Slow down',
			status: 429
		});
	});
});

describe('refresh single-flight', () => {
	/** Backend fake: data endpoints 401 until refresh has succeeded once. */
	function backend(refreshStatus: number | 'network' = 200) {
		let refreshed = false;
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async (input) => {
			const url = urlOf(input);
			if (url.endsWith('/api/v1/auth/refresh')) {
				if (refreshStatus === 'network') throw new TypeError('Failed to fetch');
				if (refreshStatus === 200) refreshed = true;
				return json(refreshStatus);
			}
			return refreshed ? json(200, { path: url }) : json(401);
		});
		const refreshCalls = () =>
			fetchMock.mock.calls.filter(([input]) => urlOf(input).endsWith('/api/v1/auth/refresh'))
				.length;
		return { fetchMock, refreshCalls, markRefreshed: () => (refreshed = true) };
	}

	it('runs one refresh for concurrent 401s and retries every request', async () => {
		const { fetchMock, refreshCalls } = backend();

		const results = await Promise.all([
			api.get<{ path: string }>('/a', { fetch: fetchMock }),
			api.get<{ path: string }>('/b', { fetch: fetchMock }),
			api.get<{ path: string }>('/c', { fetch: fetchMock })
		]);

		expect(refreshCalls()).toBe(1);
		expect(results.map((r) => r.path)).toEqual([`${BASE}/a`, `${BASE}/b`, `${BASE}/c`]);
		expect(clearSessionMock).not.toHaveBeenCalled();
	});

	it('logs out only when the refresh itself is rejected (401)', async () => {
		const { fetchMock } = backend(401);

		const err = await api.get('/a', { fetch: fetchMock }).catch((e: unknown) => e);

		expect(err).toBeInstanceOf(ApiRequestError);
		expect((err as InstanceType<typeof ApiRequestError>).code).toBe('SESSION_EXPIRED');
		expect(clearSessionMock).toHaveBeenCalledTimes(1);
		expect(gotoMock).toHaveBeenCalledWith('/auth/login');
	});

	it('does not log out on a network error during refresh', async () => {
		const { fetchMock } = backend('network');

		const err = await api.get('/a', { fetch: fetchMock }).catch((e: unknown) => e);

		expect((err as InstanceType<typeof ApiRequestError>).code).toBe('REFRESH_UNAVAILABLE');
		expect(clearSessionMock).not.toHaveBeenCalled();
		expect(gotoMock).not.toHaveBeenCalled();
	});

	it('does not log out on a 5xx from refresh', async () => {
		const { fetchMock } = backend(503);

		await expect(api.get('/a', { fetch: fetchMock })).rejects.toMatchObject({
			code: 'REFRESH_UNAVAILABLE'
		});
		expect(clearSessionMock).not.toHaveBeenCalled();
	});

	it('with Web Locks: retries the original request after waiting instead of refreshing again', async () => {
		const { fetchMock, refreshCalls, markRefreshed } = backend();
		const requestLock = vi.fn(
			async (
				_name: string,
				optsOrCb: { ifAvailable?: boolean } | ((lock: object | null) => unknown),
				maybeCb?: (lock: object | null) => unknown
			) => {
				if (typeof optsOrCb === 'object' && optsOrCb.ifAvailable && maybeCb) {
					// Another tab holds the lock and refreshes the shared cookies meanwhile.
					markRefreshed();
					return maybeCb(null);
				}
				const cb = typeof optsOrCb === 'function' ? optsOrCb : maybeCb;
				return cb ? cb({}) : undefined;
			}
		);
		vi.stubGlobal('navigator', { locks: { request: requestLock } });

		const res = await api.get<{ path: string }>('/a', { fetch: fetchMock });

		expect(res.path).toBe(`${BASE}/a`);
		expect(refreshCalls()).toBe(0);
		expect(requestLock).toHaveBeenCalledTimes(2);
	});

	it('with Web Locks available immediately: refreshes under the lock', async () => {
		const { fetchMock, refreshCalls } = backend();
		const requestLock = vi.fn(
			async (
				_name: string,
				opts: { ifAvailable?: boolean },
				cb: (lock: object | null) => unknown
			) => cb({})
		);
		vi.stubGlobal('navigator', { locks: { request: requestLock } });

		await api.get('/a', { fetch: fetchMock });

		expect(refreshCalls()).toBe(1);
		expect(requestLock).toHaveBeenCalledTimes(1);
	});

	it('treats a 401 from an auth endpoint as an answer, not an expired session', async () => {
		const { fetchMock, refreshCalls } = backend();

		await expect(
			api.post('/api/v1/auth/google', { idToken: 't' }, { fetch: fetchMock })
		).rejects.toMatchObject({ status: 401 });
		expect(refreshCalls()).toBe(0);
		expect(clearSessionMock).not.toHaveBeenCalled();
	});

	it('never refreshes or navigates on the server', async () => {
		env.browser = false;
		const { fetchMock, refreshCalls } = backend();

		await expect(api.get('/a', { fetch: fetchMock })).rejects.toMatchObject({ status: 401 });
		expect(refreshCalls()).toBe(0);
		expect(gotoMock).not.toHaveBeenCalled();
	});
});

describe('refresh race (409 REFRESH_RACE)', () => {
	afterEach(() => {
		vi.useRealTimers();
	});

	it('waits briefly and retries the original request instead of logging out', async () => {
		vi.useFakeTimers();
		let winnerCookiesLanded = false;
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async (input) => {
			if (urlOf(input).endsWith('/api/v1/auth/refresh')) {
				// Another tab won the rotation; its Set-Cookie lands shortly after.
				setTimeout(() => (winnerCookiesLanded = true), 100);
				return json(409, { error: 'Refresh raced', code: 'REFRESH_RACE' });
			}
			return winnerCookiesLanded ? json(200, { ok: true }) : json(401);
		});

		const pending = api.get<{ ok: boolean }>('/a', { fetch: fetchMock });
		await vi.advanceTimersByTimeAsync(300);

		await expect(pending).resolves.toEqual({ ok: true });
		expect(clearSessionMock).not.toHaveBeenCalled();
		expect(gotoMock).not.toHaveBeenCalled();
	});

	it('surfaces a plain 401 (no logout) if the retry still fails', async () => {
		vi.useFakeTimers();
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async (input) =>
			urlOf(input).endsWith('/api/v1/auth/refresh')
				? json(409, { code: 'REFRESH_RACE' })
				: json(401, { error: 'Unauthorized', code: 'UNAUTHORIZED' })
		);

		const pending = api.get('/a', { fetch: fetchMock }).catch((e: unknown) => e);
		await vi.advanceTimersByTimeAsync(300);
		const err = await pending;

		expect(err).toMatchObject({ status: 401, code: 'UNAUTHORIZED' });
		expect(clearSessionMock).not.toHaveBeenCalled();
	});

	it('treats a 409 without the REFRESH_RACE code as unavailable', async () => {
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async (input) =>
			urlOf(input).endsWith('/api/v1/auth/refresh') ? json(409, { code: 'OTHER' }) : json(401)
		);

		await expect(api.get('/a', { fetch: fetchMock })).rejects.toMatchObject({
			code: 'REFRESH_UNAVAILABLE'
		});
		expect(clearSessionMock).not.toHaveBeenCalled();
	});
});

describe('onSessionRefreshed', () => {
	it('notifies listeners once per successful refresh, not on failure', async () => {
		const listener = vi.fn();
		onSessionRefreshed(listener);
		let refreshed = false;
		const ok = vi.fn<FetchArgs, Promise<Response>>(async (input) => {
			if (urlOf(input).endsWith('/api/v1/auth/refresh')) {
				refreshed = true;
				return json(200);
			}
			return refreshed ? json(200) : json(401);
		});

		await Promise.all([api.get('/a', { fetch: ok }), api.get('/b', { fetch: ok })]);
		expect(listener).toHaveBeenCalledTimes(1);

		const failing = vi.fn<FetchArgs, Promise<Response>>(async (input) =>
			urlOf(input).endsWith('/api/v1/auth/refresh') ? json(503) : json(401)
		);
		await api.get('/c', { fetch: failing }).catch(() => undefined);
		expect(listener).toHaveBeenCalledTimes(1);
	});
});

describe('ensureSession', () => {
	it("returns 'ok' when the access cookie is valid", async () => {
		const fetchMock = vi.fn<FetchArgs, Promise<Response>>(async () => json(200, { id: 'u1' }));
		vi.stubGlobal('fetch', fetchMock);

		await expect(ensureSession()).resolves.toBe('ok');
		expect(urlOf(fetchMock.mock.calls[0][0])).toBe(`${BASE}/api/v1/users/me`);
	});

	it("refreshes an expired access cookie and returns 'ok'", async () => {
		let refreshed = false;
		vi.stubGlobal(
			'fetch',
			vi.fn<FetchArgs, Promise<Response>>(async (input) => {
				if (urlOf(input).endsWith('/api/v1/auth/refresh')) {
					refreshed = true;
					return json(200);
				}
				return refreshed ? json(200, { id: 'u1' }) : json(401);
			})
		);

		await expect(ensureSession()).resolves.toBe('ok');
	});

	it("returns 'expired' only when the refresh token is rejected", async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn<FetchArgs, Promise<Response>>(async () => json(401))
		);

		await expect(ensureSession()).resolves.toBe('expired');
		expect(clearSessionMock).toHaveBeenCalledTimes(1);
	});

	it("returns 'unavailable' on network errors", async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn<FetchArgs, Promise<Response>>(async () => {
				throw new TypeError('Failed to fetch');
			})
		);

		await expect(ensureSession()).resolves.toBe('unavailable');
		expect(clearSessionMock).not.toHaveBeenCalled();
	});
});
