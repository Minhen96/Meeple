/**
 * Web push through Firebase Cloud Messaging (TECH_STACK section 7, optional on web).
 *
 * The user opts in from Settings → Notifications (`enablePush`), which asks for the browser
 * permission, registers `/firebase-messaging-sw.js`, obtains an FCM token and registers it with
 * the backend as platform `web`. Logout calls `pushApi.unregister()`, which removes this
 * browser's token from the account. The backend only pushes when the user has no open
 * WebSocket, so the open app never receives duplicate alerts.
 *
 * The Firebase JS SDK is loaded on demand from Google's CDN (pinned version) only when push is
 * configured and the user opts in, so it adds nothing to the app bundle. Everything here is a
 * no-op without the VITE_FIREBASE_* env (see ./config.ts) or outside a supporting browser.
 */
import { fcmTokensApi } from '$lib/api/notifications';
import { readPushConfig, serviceWorkerUrl, type PushConfig } from './config';

const FIREBASE_VERSION = '10.14.1';
const SDK_BASE = `https://www.gstatic.com/firebasejs/${FIREBASE_VERSION}`;
/** localStorage key holding this browser's registered token (needed to unregister on logout). */
export const TOKEN_STORAGE_KEY = 'meeple_fcm_token';

// Minimal typings for the parts of the modular SDK used here.
interface FirebaseApp {
	readonly name: string;
}
interface Messaging {
	readonly app: FirebaseApp;
}
interface FirebaseAppModule {
	initializeApp(options: object, name?: string): FirebaseApp;
	getApps(): FirebaseApp[];
}
interface FirebaseMessagingModule {
	getMessaging(app: FirebaseApp): Messaging;
	getToken(
		messaging: Messaging,
		options: {
			vapidKey: string;
			serviceWorkerRegistration: ServiceWorkerRegistration;
		}
	): Promise<string>;
	deleteToken(messaging: Messaging): Promise<boolean>;
	isSupported(): Promise<boolean>;
}

export type PushStatus = 'unconfigured' | 'unsupported' | 'denied' | 'enabled' | 'disabled';

function config(): PushConfig | null {
	return readPushConfig(import.meta.env as Record<string, string | boolean | undefined>);
}

export function isPushConfigured(): boolean {
	return config() !== null;
}

function browserSupportsPush(): boolean {
	return (
		typeof window !== 'undefined' &&
		'Notification' in window &&
		'serviceWorker' in navigator &&
		'PushManager' in window
	);
}

function storedToken(): string | null {
	try {
		return localStorage.getItem(TOKEN_STORAGE_KEY);
	} catch {
		return null;
	}
}

function storeToken(token: string | null) {
	try {
		if (token) localStorage.setItem(TOKEN_STORAGE_KEY, token);
		else localStorage.removeItem(TOKEN_STORAGE_KEY);
	} catch {
		// storage blocked — unregister on logout falls back to a no-op
	}
}

/** Current state for the settings toggle. */
export function pushStatus(): PushStatus {
	if (!isPushConfigured()) return 'unconfigured';
	if (!browserSupportsPush()) return 'unsupported';
	if (Notification.permission === 'denied') return 'denied';
	return Notification.permission === 'granted' && storedToken() ? 'enabled' : 'disabled';
}

async function loadMessaging(
	cfg: PushConfig
): Promise<{ sdk: FirebaseMessagingModule; messaging: Messaging }> {
	const appModule: FirebaseAppModule = await import(
		/* @vite-ignore */ `${SDK_BASE}/firebase-app.js`
	);
	const sdk: FirebaseMessagingModule = await import(
		/* @vite-ignore */ `${SDK_BASE}/firebase-messaging.js`
	);
	if (!(await sdk.isSupported())) throw new Error('unsupported');
	const app =
		appModule.getApps().find((a) => a.name === 'meeple') ??
		appModule.initializeApp(cfg.firebase, 'meeple');
	return { sdk, messaging: sdk.getMessaging(app) };
}

function deviceInfo(): string {
	const ua = typeof navigator !== 'undefined' ? navigator.userAgent : '';
	return ua.slice(0, 255);
}

/**
 * Ask for permission and register this browser for push. Must run from a user gesture.
 * Resolves to the resulting status; never throws.
 */
export async function enablePush(): Promise<PushStatus> {
	const cfg = config();
	if (!cfg) return 'unconfigured';
	if (!browserSupportsPush()) return 'unsupported';
	try {
		const permission = await Notification.requestPermission();
		if (permission !== 'granted') return permission === 'denied' ? 'denied' : 'disabled';
		const registration = await navigator.serviceWorker.register(serviceWorkerUrl(cfg), {
			scope: '/'
		});
		const { sdk, messaging } = await loadMessaging(cfg);
		const token = await sdk.getToken(messaging, {
			vapidKey: cfg.vapidKey,
			serviceWorkerRegistration: registration
		});
		if (!token) return 'disabled';
		const previous = storedToken();
		await fcmTokensApi.register(token, 'web', deviceInfo());
		if (previous && previous !== token)
			await fcmTokensApi.unregister(previous).catch(() => undefined);
		storeToken(token);
		return 'enabled';
	} catch {
		return 'disabled';
	}
}

/** Stop push for this browser: forget the token locally, at FCM and on the account. */
export async function disablePush(): Promise<PushStatus> {
	await pushApi.unregister();
	const cfg = config();
	if (cfg && browserSupportsPush()) {
		try {
			const { sdk, messaging } = await loadMessaging(cfg);
			await sdk.deleteToken(messaging);
		} catch {
			// nothing registered or SDK unavailable
		}
	}
	return pushStatus();
}

export const pushApi = {
	/**
	 * Remove this browser's token from the signed-in account. Call before logout (while the
	 * session is still valid). No-op when push was never enabled here; never throws.
	 */
	async unregister(): Promise<void> {
		const token = storedToken();
		if (!token) return;
		storeToken(null);
		try {
			await fcmTokensApi.unregister(token);
		} catch {
			// session already gone: the backend drops the token when FCM reports it stale
		}
	}
};
