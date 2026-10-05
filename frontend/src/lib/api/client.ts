import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { clearClientSession } from '$lib/session';
import type { ApiError } from '$lib/types';

const BASE_URL = import.meta.env.VITE_API_URL as string;

const REFRESH_PATH = '/api/v1/auth/refresh';
/**
 * A 401 from an auth endpoint (bad password, unverified Google email, …) is a
 * real answer, not an expired session — never refresh/redirect for these.
 */
const AUTH_PREFIX = '/api/v1/auth/';
const REFRESH_LOCK = 'meeple-refresh';

export class ApiRequestError extends Error {
	constructor(
		public readonly code: string,
		message: string,
		public readonly status: number
	) {
		super(message);
		this.name = 'ApiRequestError';
	}
}

export type FetchFn = typeof fetch;

/**
 * Per-call options. `fetch` lets SvelteKit load functions inject their own
 * `fetch` so that SSR requests go through `handleFetch` (cookie forwarding).
 */
export interface ApiOptions extends Omit<RequestInit, 'body' | 'method'> {
	fetch?: FetchFn;
}

interface RequestOptions extends RequestInit {
	fetch?: FetchFn;
}

type RefreshOutcome = 'refreshed' | 'expired' | 'unavailable';

// ── Refresh single-flight ────────────────────────────────────────────────────
// In-tab: concurrent 401s share one refresh promise.
// Cross-tab: the refresh itself runs under a Web Lock so only one tab rotates
// the refresh token at a time. A tab that had to wait for the lock first
// re-tries its original request, because the other tab has probably already
// refreshed the (shared) cookies.

let inflightRefresh: Promise<RefreshOutcome> | null = null;

async function callRefresh(fetchFn: FetchFn): Promise<RefreshOutcome> {
	try {
		const res = await fetchFn(`${BASE_URL}${REFRESH_PATH}`, {
			method: 'POST',
			credentials: 'include',
			headers: { 'Content-Type': 'application/json' }
		});
		if (res.ok) return 'refreshed';
		// Only an explicit rejection of the refresh token ends the session.
		if (res.status === 401 || res.status === 403) return 'expired';
		return 'unavailable';
	} catch {
		// Network failure — keep the session, let the caller retry later.
		return 'unavailable';
	}
}

function getLockManager(): LockManager | null {
	if (typeof navigator === 'undefined') return null;
	return navigator.locks ?? null;
}

async function refreshUnderLock(
	fetchFn: FetchFn,
	probe: () => Promise<boolean>
): Promise<RefreshOutcome> {
	const locks = getLockManager();
	if (!locks) return callRefresh(fetchFn);

	// Fast path: nobody else is refreshing → refresh immediately.
	const immediate = await locks.request(
		REFRESH_LOCK,
		{ ifAvailable: true },
		async (lock): Promise<RefreshOutcome | null> => (lock ? callRefresh(fetchFn) : null)
	);
	if (immediate !== null) return immediate;

	// Another tab holds the lock: wait, then check whether its refresh
	// already fixed our request before rotating the token again.
	return locks.request(REFRESH_LOCK, async (): Promise<RefreshOutcome> => {
		if (await probe()) return 'refreshed';
		return callRefresh(fetchFn);
	});
}

function refreshSingleFlight(
	fetchFn: FetchFn,
	probe: () => Promise<boolean>
): Promise<RefreshOutcome> {
	if (!inflightRefresh) {
		inflightRefresh = refreshUnderLock(fetchFn, probe).finally(() => {
			inflightRefresh = null;
		});
	}
	return inflightRefresh;
}

/** Test hook — resets module-level refresh state. */
export function __resetRefreshStateForTests() {
	inflightRefresh = null;
}

// ── Core request ─────────────────────────────────────────────────────────────

function buildHeaders(options: RequestOptions | undefined): Headers {
	const headers = new Headers();
	if (!(options?.body instanceof FormData)) {
		// For FormData the browser must set multipart Content-Type with boundary.
		headers.set('Content-Type', 'application/json');
	}
	// Caller headers are merged on top of (not instead of) the computed ones.
	new Headers(options?.headers).forEach((value, key) => headers.set(key, value));
	return headers;
}

async function parseError(res: Response): Promise<ApiRequestError> {
	let err: ApiError;
	try {
		err = (await res.json()) as ApiError;
	} catch {
		err = { error: 'Request failed', code: 'UNKNOWN_ERROR' };
	}
	return new ApiRequestError(err.code || 'UNKNOWN_ERROR', err.error || 'Request failed', res.status);
}

interface PageLike {
	page?: { number: number; totalPages: number; totalElements: number };
	content?: unknown;
	number?: number;
	totalPages?: number;
	totalElements?: number;
	last?: boolean;
	first?: boolean;
}

function normalizeBody(body: unknown): unknown {
	// Unwrap the 'data' field only if it's a generic ApiResponse wrapper
	// (no pagination metadata at the top level).
	let target: unknown = body;
	if (body && typeof body === 'object' && 'data' in body) {
		const record = body as Record<string, unknown>;
		if (record.data !== undefined) {
			const keys = Object.keys(record);
			const isGenericWrapper =
				!keys.includes('meta') && !keys.includes('content') && !keys.includes('page');
			if (isGenericWrapper) target = record.data;
		}
	}

	// Normalize Spring Boot 3 Page serialization (VIA_DTO) into the classic shape.
	if (target && typeof target === 'object') {
		const page = target as PageLike;
		if (page.page && Array.isArray(page.content) && page.number === undefined) {
			page.number = page.page.number;
			page.totalPages = page.page.totalPages;
			page.totalElements = page.page.totalElements;
			page.last = page.page.number >= page.page.totalPages - 1;
			page.first = page.page.number === 0;
		}
	}

	return target ?? body;
}

async function request<T>(path: string, options?: RequestOptions): Promise<T> {
	const { fetch: injectedFetch, ...init } = options ?? {};
	const fetchFn: FetchFn = injectedFetch ?? fetch;
	const url = `${BASE_URL}${path}`;
	const headers = buildHeaders(options);

	const doFetch = () =>
		fetchFn(url, {
			credentials: 'include',
			...init,
			headers
		});

	let res = await doFetch();

	// Token refresh is a browser concern. On the server, cookies come from the
	// incoming request (see hooks.server.ts handleFetch) and the root layout
	// server load has already refreshed them if needed.
	if (res.status === 401 && browser && !path.startsWith(AUTH_PREFIX)) {
		const probed: { res: Response | null } = { res: null };
		const outcome = await refreshSingleFlight(fetchFn, async () => {
			const r = await doFetch();
			if (r.status === 401) return false;
			probed.res = r;
			return true;
		});

		if (outcome === 'expired') {
			clearClientSession();
			goto('/auth/login');
			throw new ApiRequestError('SESSION_EXPIRED', 'Session expired, please log in again', 401);
		}
		if (outcome === 'unavailable') {
			throw new ApiRequestError(
				'REFRESH_UNAVAILABLE',
				'Could not reach the server, please try again',
				0
			);
		}
		res = probed.res ?? (await doFetch());
	}

	if (!res.ok) throw await parseError(res);

	// 204 No Content
	if (res.status === 204) return undefined as T;

	const text = await res.text();
	if (!text) return undefined as T;
	return normalizeBody(JSON.parse(text)) as T;
}

function encodeBody(body: unknown): BodyInit | undefined {
	if (body instanceof FormData) return body;
	return body !== undefined ? JSON.stringify(body) : undefined;
}

export const api = {
	get: <T>(path: string, options?: ApiOptions) => request<T>(path, { ...options, method: 'GET' }),

	post: <T>(path: string, body?: unknown, options?: ApiOptions) =>
		request<T>(path, { ...options, method: 'POST', body: encodeBody(body) }),

	put: <T>(path: string, body?: unknown, options?: ApiOptions) =>
		request<T>(path, { ...options, method: 'PUT', body: encodeBody(body) }),

	patch: <T>(path: string, body?: unknown, options?: ApiOptions) =>
		request<T>(path, { ...options, method: 'PATCH', body: encodeBody(body) }),

	delete: <T>(path: string, options?: ApiOptions) =>
		request<T>(path, { ...options, method: 'DELETE' })
};

/**
 * Upload a file directly to a presigned object-storage URL (Cloudflare R2).
 * This intentionally bypasses the API base URL, credentials and refresh logic:
 * the URL itself carries the authorization.
 */
export async function putToPresignedUrl(uploadUrl: string, file: File): Promise<void> {
	const res = await fetch(uploadUrl, {
		method: 'PUT',
		body: file,
		headers: { 'Content-Type': file.type }
	});
	if (!res.ok) {
		throw new ApiRequestError('UPLOAD_FAILED', 'Failed to upload file to storage', res.status);
	}
}
