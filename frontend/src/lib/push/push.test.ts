import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { register, unregister } = vi.hoisted(() => ({
	register: vi.fn<[string, string, string?], Promise<void>>(),
	unregister: vi.fn<[string], Promise<void>>()
}));
vi.mock('$lib/api/notifications', () => ({
	fcmTokensApi: { register, unregister }
}));

import { readPushConfig, serviceWorkerUrl } from './config';
import {
	TOKEN_STORAGE_KEY,
	disablePush,
	enablePush,
	isPushConfigured,
	pushApi,
	pushStatus
} from './fcm';

const FULL = {
	VITE_FIREBASE_API_KEY: 'key',
	VITE_FIREBASE_PROJECT_ID: 'proj',
	VITE_FIREBASE_MESSAGING_SENDER_ID: '123',
	VITE_FIREBASE_APP_ID: '1:123:web:abc',
	VITE_FIREBASE_VAPID_KEY: 'vapid'
};

describe('readPushConfig', () => {
	it('needs every required value', () => {
		expect(readPushConfig(FULL)?.vapidKey).toBe('vapid');
		expect(readPushConfig({ ...FULL, VITE_FIREBASE_VAPID_KEY: ' ' })).toBeNull();
		expect(readPushConfig({ ...FULL, VITE_FIREBASE_APP_ID: undefined })).toBeNull();
		expect(readPushConfig({})).toBeNull();
	});

	it('keeps the optional auth domain and builds the worker URL', () => {
		const cfg = readPushConfig({
			...FULL,
			VITE_FIREBASE_AUTH_DOMAIN: 'proj.firebaseapp.com'
		});
		expect(cfg?.firebase.authDomain).toBe('proj.firebaseapp.com');
		const url = new URL(serviceWorkerUrl(cfg!), 'https://meeple.test');
		expect(url.pathname).toBe('/firebase-messaging-sw.js');
		expect(url.searchParams.get('apiKey')).toBe('key');
		expect(url.searchParams.get('authDomain')).toBe('proj.firebaseapp.com');
		expect(
			new URL(serviceWorkerUrl(readPushConfig(FULL)!), 'https://x.test').searchParams.has(
				'authDomain'
			)
		).toBe(false);
	});
});

describe('without VITE_FIREBASE_* config', () => {
	const storage = new Map<string, string>();

	beforeEach(() => {
		storage.clear();
		vi.stubGlobal('localStorage', {
			getItem: (k: string) => storage.get(k) ?? null,
			setItem: (k: string, v: string) => storage.set(k, v),
			removeItem: (k: string) => storage.delete(k)
		});
		register.mockReset();
		unregister.mockReset();
	});

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('is a no-op', async () => {
		expect(isPushConfigured()).toBe(false);
		expect(pushStatus()).toBe('unconfigured');
		expect(await enablePush()).toBe('unconfigured');
		expect(register).not.toHaveBeenCalled();
		expect(await disablePush()).toBe('unconfigured');
	});

	it('pushApi.unregister removes a stored token once and tolerates failures', async () => {
		await pushApi.unregister();
		expect(unregister).not.toHaveBeenCalled();

		storage.set(TOKEN_STORAGE_KEY, 'tok');
		unregister.mockRejectedValueOnce(new Error('401'));
		await pushApi.unregister();
		expect(unregister).toHaveBeenCalledWith('tok');
		expect(storage.has(TOKEN_STORAGE_KEY)).toBe(false);

		await pushApi.unregister();
		expect(unregister).toHaveBeenCalledTimes(1);

		storage.set(TOKEN_STORAGE_KEY, JSON.stringify({ token: 'tok2', userId: 'u1' }));
		await pushApi.unregister();
		expect(unregister).toHaveBeenLastCalledWith('tok2');
		expect(storage.has(TOKEN_STORAGE_KEY)).toBe(false);
	});
});
