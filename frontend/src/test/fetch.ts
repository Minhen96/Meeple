// Shared fetch helpers for tests that drive the real API client (src/lib/api/client.ts)
// against a mocked global fetch.
import { vi, type Mock } from 'vitest';

export const API_BASE = 'http://api.test';

type FetchArgs = [input: RequestInfo | URL, init?: RequestInit];
export type FetchMock = Mock<FetchArgs, Promise<Response>>;

export function jsonResponse(status: number, body?: unknown, headers?: HeadersInit): Response {
	if (status === 204) return new Response(null, { status });
	return new Response(body === undefined ? '' : JSON.stringify(body), {
		status,
		headers: { 'Content-Type': 'application/json', ...(headers ?? {}) }
	});
}

/** Replace global fetch; by default every call answers 200 `{}`. */
export function installFetch(
	handler: (url: string, init: RequestInit) => Response | Promise<Response> = () =>
		jsonResponse(200, {})
): FetchMock {
	const mock: FetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) =>
		handler(urlOf(input), init ?? {})
	);
	vi.stubGlobal('fetch', mock);
	return mock;
}

export function urlOf(input: RequestInfo | URL): string {
	if (typeof input === 'string') return input;
	return input instanceof URL ? input.href : input.url;
}

export interface RecordedCall {
	url: string;
	/** URL without the API base, e.g. `/api/v1/posts?limit=20`. */
	path: string;
	method: string;
	body: unknown;
	rawBody: BodyInit | null | undefined;
	headers: Headers;
}

export function callAt(mock: FetchMock, index: number): RecordedCall {
	const call = mock.mock.calls.at(index);
	if (!call) throw new Error(`no fetch call at index ${index}`);
	const [input, init = {}] = call;
	const url = urlOf(input);
	const raw = init.body;
	let body: unknown = raw;
	if (typeof raw === 'string') {
		try {
			body = JSON.parse(raw);
		} catch {
			body = raw;
		}
	}
	return {
		url,
		path: url.startsWith(API_BASE) ? url.slice(API_BASE.length) : url,
		method: init.method ?? 'GET',
		body,
		rawBody: raw,
		headers: new Headers(init.headers)
	};
}

export const lastCall = (mock: FetchMock) => callAt(mock, -1);
