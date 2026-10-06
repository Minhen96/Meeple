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
import { get } from 'svelte/store';
import { fcmTokensApi } from '$lib/api/notifications';
import { currentUser } from '$lib/stores/auth';
import { readPushConfig, serviceWorkerUrl, type PushConfig } from './config';

const FIREBASE_VERSION = '10.14.1';
const SDK_BASE = `https://www.gstatic.com/firebasejs/${FIREBASE_VERSION}`;
/**
 * localStorage key holding this browser's registered token and the account it was registered
 * for, as JSON `{token, userId}` (needed to unregister on logout and to notice an account switch).
 */
export const TOKEN_STORAGE_KEY = 'meeple_fcm_token';

/** The token this browser registered, and for which account (null: unknown, legacy entry). */
export interface StoredPushToken {
	token: string;
	userId: string | null;
}

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

function readStored(): StoredPushToken | null {
	let raw: string | null;
	try {
		raw = localStorage.getItem(TOKEN_STORAGE_KEY);
	} catch {
		return null;
	}
	if (!raw) return null;
	try {
		const value: unknown = JSON.parse(raw);
		if (typeof value === 'object' && value !== null) {
			const rec = value as Record<string, unknown>;
			if (typeof rec.token === 'string' && rec.token) {
				return { token: rec.token, userId: typeof rec.userId === 'string' ? rec.userId : null };
			}
		}
	} catch {
		// legacy entry: the bare token string, owner unknown
	}
	return { token: raw, userId: null };
}

function storeToken(entry: StoredPushToken | null) {
	try {
		if (entry) localStorage.setItem(TOKEN_STORAGE_KEY, JSON.stringify(entry));
		else localStorage.removeItem(TOKEN_STORAGE_KEY);
	} catch {
		// storage blocked — unregister on logout falls back to a no-op
	}
}

function currentUserId(): string | null {
	return get(currentUser)?.id ?? null;
}

/** Current state for the settings toggle. */
export function pushStatus(): PushStatus {
	if (!isPushConfigured()) return 'unconfigured';
	if (!browserSupportsPush()) return 'unsupported';
	if (Notification.permission === 'denied') return 'denied';
	const stored = readStored();
	// A token registered for another account (shared browser) is not this user's push.
	const mine = stored !== null && stored.userId !== null && stored.userId === currentUserId();
	return Notification.permission === 'granted' && mine ? 'enabled' : 'disabled';
}

/**
 * Reconcile this browser's stored token with the signed-in account (call whenever the user
 * changes). A token left behind by another account is moved to the current one when the browser
 * still grants permission (the backend re-assigns a token to whoever registered it last), and is
 * forgotten otherwise. Never throws.
 */
export async function syncPushUser(userId: string | null): Promise<void> {
	if (!userId) return;
	const stored = readStored();
	if (!stored || stored.userId === userId) return;
	if (
		!isPushConfigured() ||
		!browserSupportsPush() ||
		Notification.permission !== 'granted'
	) {
		storeToken(null);
		return;
	}
	try {
		await fcmTokensApi.register(stored.token, 'web', deviceInfo());
		storeToken({ token: stored.token, userId });
	} catch {
		storeToken(null);
	}
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
		const previous = readStored()?.token;
		await fcmTokensApi.register(token, 'web', deviceInfo());
		if (previous && previous !== token)
			await fcmTokensApi.unregister(previous).catch(() => undefined);
		storeToken({ token, userId: currentUserId() });
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
		const token = readStored()?.token;
		if (!token) return;
		storeToken(null);
		try {
			await fcmTokensApi.unregister(token);
		} catch {
			// session already gone: the backend drops the token when FCM reports it stale
		}
	}
};
