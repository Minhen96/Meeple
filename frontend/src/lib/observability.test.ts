// Env-gated Sentry / PostHog wiring. Only the user id may ever be attached (CLAUDE.md: no PII).
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const sentry = vi.hoisted(() => ({
	init: vi.fn(),
	setUser: vi.fn(),
	captureException: vi.fn()
}));
const posthog = vi.hoisted(() => ({
	init: vi.fn(),
	identify: vi.fn(),
	reset: vi.fn(),
	capture: vi.fn()
}));
vi.mock('@sentry/sveltekit', () => sentry);
vi.mock('posthog-js', () => ({ default: posthog }));

type Obs = typeof import('./observability');

async function fresh(envVars: Record<string, string>, withWindow = true): Promise<Obs> {
	vi.resetModules();
	for (const [k, v] of Object.entries(envVars)) vi.stubEnv(k, v);
	if (withWindow) vi.stubGlobal('window', {});
	return import('./observability');
}

beforeEach(() => {
	for (const fn of [...Object.values(sentry), ...Object.values(posthog)]) fn.mockReset();
});

afterEach(() => {
	vi.unstubAllEnvs();
	vi.unstubAllGlobals();
});

describe('observability', () => {
	it('loads nothing without keys, and every call is a no-op', async () => {
		const obs = await fresh({ VITE_SENTRY_DSN: '', VITE_POSTHOG_KEY: '' });
		await obs.initObservability();
		obs.identifyUser('u1');
		obs.captureError(new Error('x'));
		obs.track('evt');
		expect(sentry.init).not.toHaveBeenCalled();
		expect(posthog.init).not.toHaveBeenCalled();
		expect(sentry.captureException).not.toHaveBeenCalled();
	});

	it('does nothing during SSR (no window)', async () => {
		const obs = await fresh({ VITE_SENTRY_DSN: 'https://dsn', VITE_POSTHOG_KEY: 'phk' }, false);
		await obs.initObservability();
		expect(sentry.init).not.toHaveBeenCalled();
	});

	it('initialises both SDKs once with privacy-preserving options', async () => {
		const obs = await fresh({
			VITE_SENTRY_DSN: 'https://dsn',
			VITE_SENTRY_ENVIRONMENT: 'staging',
			VITE_POSTHOG_KEY: 'phk',
			VITE_POSTHOG_HOST: 'https://eu.posthog.test'
		});
		await obs.initObservability();
		await obs.initObservability();
		expect(sentry.init).toHaveBeenCalledTimes(1);
		expect(sentry.init.mock.calls[0][0]).toMatchObject({
			dsn: 'https://dsn',
			environment: 'staging',
			tracesSampleRate: 0,
			dataCollection: { userInfo: false, cookies: false, httpHeaders: false, urlQueryParams: false }
		});
		expect(posthog.init).toHaveBeenCalledWith(
			'phk',
			expect.objectContaining({ api_host: 'https://eu.posthog.test', persistence: 'memory', capture_pageview: false })
		);

		obs.captureError('boom');
		expect(sentry.captureException).toHaveBeenCalledWith('boom');
		obs.track('post_created', { n: 1 });
		expect(posthog.capture).toHaveBeenCalledWith('post_created', { n: 1 });
	});

	it('uses default host / environment when not configured', async () => {
		const obs = await fresh({ VITE_SENTRY_DSN: 'https://dsn', VITE_SENTRY_ENVIRONMENT: '', VITE_POSTHOG_KEY: 'phk', VITE_POSTHOG_HOST: '' });
		await obs.initObservability();
		expect(sentry.init.mock.calls[0][0].environment).toBe(import.meta.env.MODE);
		expect(posthog.init.mock.calls[0][1].api_host).toBe('https://us.i.posthog.com');
	});

	it('attaches only the user id, applies an identity set before init, and dedupes', async () => {
		const obs = await fresh({ VITE_SENTRY_DSN: 'https://dsn', VITE_POSTHOG_KEY: 'phk' });
		obs.identifyUser('u1');
		expect(sentry.setUser).not.toHaveBeenCalled();
		await obs.initObservability();
		expect(sentry.setUser).toHaveBeenCalledWith({ id: 'u1' });
		expect(posthog.identify).toHaveBeenCalledWith('u1');

		obs.identifyUser('u1');
		expect(sentry.setUser).toHaveBeenCalledTimes(1);

		obs.identifyUser(null);
		expect(sentry.setUser).toHaveBeenLastCalledWith(null);
		expect(posthog.reset).toHaveBeenCalled();
	});

	it('warns but does not throw when an SDK fails to load', async () => {
		vi.doMock('@sentry/sveltekit', () => {
			throw new Error('blocked by adblock');
		});
		const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
		const obs = await fresh({ VITE_SENTRY_DSN: 'https://dsn', VITE_POSTHOG_KEY: '' });
		await expect(obs.initObservability()).resolves.toBeUndefined();
		expect(warn).toHaveBeenCalledWith('Observability SDK failed to load', expect.anything());
		vi.doUnmock('@sentry/sveltekit');
		vi.doMock('@sentry/sveltekit', () => sentry);
		warn.mockRestore();
	});
});
