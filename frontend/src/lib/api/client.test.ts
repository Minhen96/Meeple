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

const { api, ApiRequestError, __resetRefreshStateForTests } = await import('./client');

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
