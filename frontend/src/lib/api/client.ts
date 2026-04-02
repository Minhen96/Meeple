import type { ApiError } from '$lib/types';

const BASE_URL = import.meta.env.VITE_API_URL as string;

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

async function request<T>(path: string, options?: RequestInit): Promise<T> {
	const res = await fetch(`${BASE_URL}${path}`, {
		credentials: 'include', // sends httpOnly cookie automatically
		headers: {
			'Content-Type': 'application/json',
			...options?.headers
		},
		...options
	});

	if (!res.ok) {
		let err: ApiError;
		try {
			err = await res.json();
		} catch {
			err = { error: 'Request failed', code: 'UNKNOWN_ERROR' };
		}
		throw new ApiRequestError(err.code, err.error, res.status);
	}

	// 204 No Content
	if (res.status === 204) return undefined as T;

	const body = await res.json();
	
	// Normalize Spring Boot 3 Page serialization universally
	// We unwrap the 'data' field only if it's a generic ApiResponse wrapper
	let target = body;
	if (body && typeof body === 'object' && 'data' in body && body.data !== undefined) {
		const keys = Object.keys(body);
		// Only unwrap if it's a simple wrapper (has data, but no pagination metadata at the top level)
		const isGenericWrapper = !keys.includes('meta') && !keys.includes('content') && !keys.includes('page');
		if (isGenericWrapper) {
			target = body.data;
		}
	}
	
	// Ensure target is valid before further normalization
	if (target && typeof target === 'object' && target.page && Array.isArray(target.content)) {
		if (target.number === undefined) {
			target.number = target.page.number;
			target.totalPages = target.page.totalPages;
			target.totalElements = target.page.totalElements;
			target.last = target.page.number >= target.page.totalPages - 1;
			target.first = target.page.number === 0;
		}
	}
	
	// Default to body if target somehow became null/undefined but body is valid
	return (target ?? body) as T;
}

export const api = {
	get: <T>(path: string) => request<T>(path),

	post: <T>(path: string, body?: unknown) =>
		request<T>(path, {
			method: 'POST',
			body: body !== undefined ? JSON.stringify(body) : undefined
		}),

	put: <T>(path: string, body?: unknown) =>
		request<T>(path, {
			method: 'PUT',
			body: body !== undefined ? JSON.stringify(body) : undefined
		}),

	patch: <T>(path: string, body?: unknown) =>
		request<T>(path, {
			method: 'PATCH',
			body: body !== undefined ? JSON.stringify(body) : undefined
		}),

	delete: <T>(path: string) => request<T>(path, { method: 'DELETE' })
};
