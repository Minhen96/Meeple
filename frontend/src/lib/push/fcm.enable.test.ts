// @vitest-environment jsdom
// enablePush / disablePush with push configured, a fake browser and a fake Firebase SDK.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const h = vi.hoisted(() => ({
	register: vi.fn(async (..._a: unknown[]) => {}),
	unregister: vi.fn(async (..._a: unknown[]) => {}),
	getToken: vi.fn(async (..._a: unknown[]) => 'tok-1'),
	deleteToken: vi.fn(async (..._a: unknown[]) => true),
	isSupported: vi.fn(async () => true),
	initializeApp: vi.fn((_o: object, name: string) => ({ name })),
	getApps: vi.fn((): Array<{ name: string }> => [])
}));
vi.mock('$lib/api/notifications', () => ({
	fcmTokensApi: { register: h.register, unregister: h.unregister }
}));
vi.mock('https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js', () => ({
	initializeApp: h.initializeApp,
	getApps: h.getApps
}));
vi.mock('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging.js', () => ({
	getMessaging: (app: { name: string }) => ({ app }),
	getToken: h.getToken,
	deleteToken: h.deleteToken,
	isSupported: h.isSupported
}));

const ENV = {
	VITE_FIREBASE_API_KEY: 'key',
	VITE_FIREBASE_PROJECT_ID: 'proj',
	VITE_FIREBASE_MESSAGING_SENDER_ID: '123',
	VITE_FIREBASE_APP_ID: '1:123:web:abc',
	VITE_FIREBASE_VAPID_KEY: 'vapid'
};
for (const [k, v] of Object.entries(ENV)) vi.stubEnv(k, v);

const { TOKEN_STORAGE_KEY, disablePush, enablePush, isPushConfigured, pushStatus } = await import('./fcm');

let permission: NotificationPermission;
const swRegister = vi.fn(async (..._a: unknown[]) => ({ scope: '/' }) as unknown as ServiceWorkerRegistration);

beforeEach(() => {
	localStorage.clear();
	permission = 'default';
	for (const fn of Object.values(h)) fn.mockClear();
	h.getToken.mockResolvedValue('tok-1');
	h.isSupported.mockResolvedValue(true);
	h.getApps.mockReturnValue([]);
	swRegister.mockClear();
	vi.stubGlobal('Notification', {
		get permission() {
			return permission;
		},
		requestPermission: vi.fn(async () => permission)
	});
	vi.stubGlobal('PushManager', function PushManager() {});
	Object.defineProperty(navigator, 'serviceWorker', {
		value: { register: swRegister },
		configurable: true
	});
});

afterEach(() => {
	vi.unstubAllGlobals();
	// @ts-expect-error test cleanup of the fake service worker container
	delete navigator.serviceWorker;
});

describe('with push configured', () => {
	it('reports configured and disabled before opting in', () => {
		expect(isPushConfigured()).toBe(true);
		expect(pushStatus()).toBe('disabled');
	});

	it('enables: permission → service worker → FCM token → backend registration', async () => {
		permission = 'granted';
		await expect(enablePush()).resolves.toBe('enabled');
		expect(swRegister).toHaveBeenCalledWith(expect.stringContaining('firebase-messaging-sw.js'), { scope: '/' });
		expect(h.initializeApp).toHaveBeenCalledWith(expect.objectContaining({ apiKey: 'key' }), 'meeple');
		expect(h.getToken).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({ vapidKey: 'vapid' }));
		expect(h.register).toHaveBeenCalledWith('tok-1', 'web', expect.any(String));
		expect(localStorage.getItem(TOKEN_STORAGE_KEY)).toBe('tok-1');
		expect(pushStatus()).toBe('enabled');
	});

	it('reuses an existing Firebase app and unregisters a rotated token', async () => {
		permission = 'granted';
		localStorage.setItem(TOKEN_STORAGE_KEY, 'old');
		h.getApps.mockReturnValue([{ name: 'meeple' }]);
		h.unregister.mockRejectedValueOnce(new Error('gone'));
		await expect(enablePush()).resolves.toBe('enabled');
		expect(h.initializeApp).not.toHaveBeenCalled();
		expect(h.unregister).toHaveBeenCalledWith('old');
		expect(localStorage.getItem(TOKEN_STORAGE_KEY)).toBe('tok-1');
	});

	it.each([
		['denied', 'denied'],
		['default', 'disabled']
	] as const)('permission %s -> %s without registering', async (perm, expected) => {
		permission = perm;
		await expect(enablePush()).resolves.toBe(expected);
		expect(h.register).not.toHaveBeenCalled();
		if (perm === 'denied') expect(pushStatus()).toBe('denied');
	});

	it('returns disabled when FCM gives no token, the SDK is unsupported or anything throws', async () => {
		permission = 'granted';
		h.getToken.mockResolvedValueOnce('');
		await expect(enablePush()).resolves.toBe('disabled');
		h.isSupported.mockResolvedValueOnce(false);
		await expect(enablePush()).resolves.toBe('disabled');
		h.register.mockRejectedValueOnce(new Error('401'));
		await expect(enablePush()).resolves.toBe('disabled');
		expect(localStorage.getItem(TOKEN_STORAGE_KEY)).toBeNull();
	});

	it('is unsupported without the browser APIs', async () => {
		vi.stubGlobal('PushManager', undefined);
		// `'PushManager' in window` stays true for an undefined stub, so remove it outright.
		delete (window as unknown as Record<string, unknown>).PushManager;
		expect(pushStatus()).toBe('unsupported');
		await expect(enablePush()).resolves.toBe('unsupported');
	});

	it('disable removes the token from the account, deletes it at FCM and reports the new status', async () => {
		permission = 'granted';
		localStorage.setItem(TOKEN_STORAGE_KEY, 'tok-1');
		await expect(disablePush()).resolves.toBe('disabled');
		expect(h.unregister).toHaveBeenCalledWith('tok-1');
		expect(h.deleteToken).toHaveBeenCalled();
		expect(localStorage.getItem(TOKEN_STORAGE_KEY)).toBeNull();
	});

	it('disable tolerates an SDK failure', async () => {
		h.isSupported.mockResolvedValueOnce(false);
		await expect(disablePush()).resolves.toBe('disabled');
		expect(h.deleteToken).not.toHaveBeenCalled();
	});
});
