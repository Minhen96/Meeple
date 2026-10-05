// hooks.server.ts (locale + SSR cookie forwarding) and hooks.client.ts (error reporting).
import { describe, expect, it, vi, beforeEach } from 'vitest';

const obs = vi.hoisted(() => ({ captureError: vi.fn(), initObservability: vi.fn(async () => {}) }));
vi.mock('$lib/observability', () => obs);
vi.stubEnv('VITE_API_URL', 'https://api.meeple.test');

const serverHooks = await import('./hooks.server');
const clientHooks = await import('./hooks.client');

type HandleEvent = Parameters<typeof serverHooks.handle>[0]['event'];

function handleEvent(cookies: Record<string, string>, acceptLanguage: string | null) {
	const headers = new Headers();
	if (acceptLanguage) headers.set('accept-language', acceptLanguage);
	return {
		cookies: { get: (n: string) => cookies[n] },
		request: new Request('https://app.test/', { headers }),
		locals: {} as Record<string, unknown>
	} as unknown as HandleEvent & { locals: Record<string, unknown> };
}

async function runHandle(cookies: Record<string, string>, acceptLanguage: string | null) {
	const event = handleEvent(cookies, acceptLanguage);
	let html = '';
	const resolve = vi.fn(async (_e: unknown, opts?: { transformPageChunk?: (a: { html: string; done: boolean }) => string }) => {
		html = opts?.transformPageChunk?.({ html: '<html lang="%lang%">', done: true }) ?? '';
		return new Response(html);
	});
	await serverHooks.handle({ event, resolve } as never);
	return { locale: event.locals.locale, html };
}

describe('handle (locale)', () => {
	it('uses a valid locale cookie', async () => {
		expect(await runHandle({ lang: 'zh-CN' }, 'en-US')).toEqual({ locale: 'zh-CN', html: '<html lang="zh-CN">' });
	});

	it('falls back to Accept-Language when the cookie is missing or invalid', async () => {
		expect((await runHandle({ lang: 'xx' }, 'zh-CN,zh;q=0.9')).locale).toBe('zh-CN');
		expect((await runHandle({}, null)).locale).toBe('en');
	});
});

describe('handleFetch (SSR cookie forwarding)', () => {
	type FetchEvent = Parameters<typeof serverHooks.handleFetch>[0];

	async function runFetch(url: string, opts: { browserCookie?: string; locals?: Record<string, string>; headers?: Record<string, string> } = {}) {
		const request = new Request(url, { headers: opts.headers });
		const fetch = vi.fn(async (r: Request) => new Response(r.headers.get('cookie') ?? ''));
		const event = {
			request: new Request('https://app.test/page', {
				headers: opts.browserCookie ? { cookie: opts.browserCookie } : {}
			}),
			locals: opts.locals ?? {}
		};
		await serverHooks.handleFetch({ event, request, fetch } as unknown as FetchEvent);
		return fetch.mock.calls[0][0];
	}

	it('forwards the browser cookie to the API origin', async () => {
		const req = await runFetch('https://api.meeple.test/api/v1/users/me', { browserCookie: 'access_token=a1; theme=dark' });
		expect(req.headers.get('cookie')).toContain('access_token=a1');
		expect(req.headers.get('authorization')).toBeNull();
	});

	it('prefers tokens rotated earlier in this request and adds a bearer header', async () => {
		const req = await runFetch('https://api.meeple.test/api/v1/feed', {
			browserCookie: 'access_token=old; refresh_token=oldr',
			locals: { accessToken: 'new', refreshToken: 'newr' }
		});
		expect(req.headers.get('cookie')).toContain('access_token=new');
		expect(req.headers.get('cookie')).toContain('refresh_token=newr');
		expect(req.headers.get('cookie')).not.toContain('old');
		expect(req.headers.get('authorization')).toBe('Bearer new');
	});

	it('respects explicit cookie / authorization headers', async () => {
		const req = await runFetch('https://api.meeple.test/api/v1/auth/refresh', {
			browserCookie: 'access_token=a1',
			locals: { accessToken: 'new' },
			headers: { cookie: 'refresh_token=explicit', authorization: 'Bearer explicit' }
		});
		expect(req.headers.get('cookie')).toBe('refresh_token=explicit');
		expect(req.headers.get('authorization')).toBe('Bearer explicit');
	});

	it('sets no cookie header when there is nothing to forward', async () => {
		const req = await runFetch('https://api.meeple.test/api/v1/x');
		expect(req.headers.has('cookie')).toBe(false);
	});

	it('never forwards cookies to other origins', async () => {
		const req = await runFetch('https://evil.test/steal', { browserCookie: 'access_token=a1', locals: { accessToken: 'a1' } });
		expect(req.headers.has('cookie')).toBe(false);
		expect(req.headers.has('authorization')).toBe(false);
	});
});

describe('client hooks', () => {
	beforeEach(() => {
		obs.captureError.mockReset();
	});

	it('init starts observability', () => {
		clientHooks.init?.();
		expect(obs.initObservability).toHaveBeenCalled();
	});

	it('reports only 5xx errors', () => {
		const handle = clientHooks.handleError as (input: { error: unknown; status: number }) => void;
		handle({ error: new Error('404'), status: 404 });
		expect(obs.captureError).not.toHaveBeenCalled();
		const boom = new Error('boom');
		handle({ error: boom, status: 500 });
		expect(obs.captureError).toHaveBeenCalledWith(boom);
	});
});
