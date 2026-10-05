import { Client, type IMessage, type StompSubscription } from '@stomp/stompjs';
import { ensureSession, onSessionRefreshed } from '$lib/api/client';
import { notificationsApi } from '$lib/api/notifications';
import { handleNotificationFrame, resetNotifications, setUnreadCount } from './notifications';

const API_URL = import.meta.env.VITE_API_URL as string;

/** Per-user notifications (Spring user destination, resolved from the authenticated principal). */
const NOTIFICATIONS_DESTINATION = '/user/queue/notifications';

function wsUrl(): string {
	return API_URL.replace(/^http/, 'ws') + '/ws';
}

let stompClient: Client | null = null;

/** True between connectWS() and disconnectWS(): a logged-in user wants realtime. */
let wanted = false;

/**
 * Consecutive STOMP ERROR frames before we pause reconnecting. Each attempt
 * first refreshes the access cookie (beforeConnect), so errors here are not an
 * expired session; pausing just avoids a tight loop. A successful token
 * refresh, the tab becoming visible or the browser coming back online resumes.
 */
const MAX_CONSECUTIVE_STOMP_ERRORS = 3;
let consecutiveErrors = 0;

// ── Topic registry ───────────────────────────────────────────────────────────
// Every subscription lives here and is (re)attached in onConnect after each
// (re)connect, so callers can subscribe before the socket is up and survive
// reconnects without wrapping onConnect.

interface TopicEntry {
	topic: string;
	callback: (message: IMessage) => void;
	live: StompSubscription | null;
}

const registry = new Set<TopicEntry>();

function attach(entry: TopicEntry) {
	if (!stompClient?.connected) {
		entry.live = null;
		return;
	}
	entry.live = stompClient.subscribe(entry.topic, entry.callback);
}

/**
 * Subscribe to a STOMP destination. Safe to call before the socket connects.
 * Returns an unsubscribe function — call it in onDestroy.
 */
export function subscribeTopic(topic: string, callback: (message: IMessage) => void): () => void {
	const entry: TopicEntry = { topic, callback, live: null };
	registry.add(entry);
	attach(entry);

	return () => {
		if (!registry.delete(entry)) return;
		if (entry.live && stompClient?.connected) {
			try {
				entry.live.unsubscribe();
			} catch {
				// connection dropped between the check and the call — nothing to clean up
			}
		}
		entry.live = null;
	};
}

/** Frames are `{notification, unreadCount}` (docs/GAP_ANALYSIS.md section 6.3); malformed ones are ignored. */
function handleNotification(message: IMessage) {
	handleNotificationFrame(message.body);
}

/**
 * Resync the badge after every (re)connect: frames sent while the socket was down were missed.
 * Failures keep the last known value.
 */
async function syncUnreadCount() {
	try {
		setUnreadCount(await notificationsApi.getUnreadCount());
	} catch {
		// offline or session expired — the next connect retries
	}
}

function startClient() {
	if (stompClient?.active) return;

	const client = new Client({
		brokerURL: wsUrl(),
		reconnectDelay: 5000,
		// Runs before every (re)connect attempt. The access cookie lives 15 min,
		// so after a long drop the upgrade would be rejected; this refreshes it
		// first through the API client's single-flight refresh.
		beforeConnect: async () => {
			const session = await ensureSession();
			// 'expired': the API client already cleared the session (which calls
			// disconnectWS); make sure this client does not connect regardless.
			if (session === 'expired' && stompClient === client) disconnectWS();
		},
		onConnect: () => {
			consecutiveErrors = 0;
			client.subscribe(NOTIFICATIONS_DESTINATION, handleNotification);
			registry.forEach(attach);
			void syncUnreadCount();
		},
		onStompError: () => {
			consecutiveErrors++;
			if (consecutiveErrors >= MAX_CONSECUTIVE_STOMP_ERRORS && stompClient === client) {
				stopClient();
			}
		},
		onWebSocketClose: () => {
			// Subscriptions die with the socket; they are re-attached on reconnect.
			registry.forEach((entry) => {
				entry.live = null;
			});
		}
	});

	stompClient = client;
	client.activate();
}

function stopClient() {
	const client = stompClient;
	stompClient = null;
	registry.forEach((entry) => {
		entry.live = null;
	});
	void client?.deactivate();
}

/**
 * Restart the connection if the user is logged in but the client has stopped
 * (paused after repeated errors). Called after a successful token refresh and
 * when the tab becomes visible / the browser comes back online. No-op while a
 * client is active (it reconnects by itself and picks up the new cookie).
 */
export function reconnectWS() {
	if (!wanted) return;
	consecutiveErrors = 0;
	if (stompClient?.active) return;
	startClient();
}

function handleVisibilityChange() {
	if (document.visibilityState === 'visible') reconnectWS();
}

let browserListenersAttached = false;

function setBrowserListeners(attachListeners: boolean) {
	if (typeof window === 'undefined' || attachListeners === browserListenersAttached) return;
	browserListenersAttached = attachListeners;
	if (attachListeners) {
		document.addEventListener('visibilitychange', handleVisibilityChange);
		window.addEventListener('online', reconnectWS);
	} else {
		document.removeEventListener('visibilitychange', handleVisibilityChange);
		window.removeEventListener('online', reconnectWS);
	}
}

// Registered lazily (first connectWS), not at module load: client.ts →
// session.ts → this module is an import cycle, so client.ts may not be
// initialised yet while this module evaluates.
let refreshListenerRegistered = false;

/**
 * Connect to the STOMP broker for the logged-in user.
 *
 * Web auth: the backend reads the httpOnly access_token cookie from the
 * WebSocket upgrade request, so no Authorization connect header is sent
 * (JS cannot read the cookie). Mobile clients pass the JWT in the CONNECT
 * frame instead.
 *
 * No-op if a client is already active (connecting, connected or reconnecting).
 */
export function connectWS() {
	wanted = true;
	consecutiveErrors = 0;
	if (!refreshListenerRegistered) {
		refreshListenerRegistered = true;
		onSessionRefreshed(reconnectWS);
	}
	setBrowserListeners(true);
	startClient();
}

/** Disconnect and stop reconnecting (logout, session expired, user changed). */
export function disconnectWS() {
	wanted = false;
	setBrowserListeners(false);
	stopClient();
	resetNotifications();
}

// ── How-to-play progress ─────────────────────────────────────────────────────

export interface HowToPlayProgressMessage {
	/**
	 * 'failed' is the terminal failure message (carries errorMessage).
	 * 'error' is the legacy failure status from older backends — treated the same.
	 */
	status: 'generating' | 'ready' | 'failed' | 'error';
	progress: number;
	errorMessage?: string | null;
}

/**
 * Subscribe to how-to-play progress updates for a game.
 * Returns an unsubscribe function — call it in onDestroy.
 */
export function subscribeToHowToPlayProgress(
	gameId: string,
	onMessage: (msg: HowToPlayProgressMessage) => void
): () => void {
	return subscribeTopic(`/topic/how-to-play/${gameId}`, (frame) => {
		try {
			onMessage(JSON.parse(frame.body) as HowToPlayProgressMessage);
		} catch {
			// ignore malformed frames
		}
	});
}
