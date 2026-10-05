import { Client, type IMessage, type StompSubscription } from '@stomp/stompjs';
import { addNotification } from './notifications';
import type { Notification } from '$lib/types';

const API_URL = import.meta.env.VITE_API_URL as string;

/** Per-user notifications (Spring user destination, resolved from the authenticated principal). */
const NOTIFICATIONS_DESTINATION = '/user/queue/notifications';

function wsUrl(): string {
	return API_URL.replace(/^http/, 'ws') + '/ws';
}

let stompClient: Client | null = null;

/**
 * Consecutive STOMP ERROR frames (e.g. CONNECT rejected because the session
 * expired) before we stop reconnecting. A later connectWS() — triggered when
 * the user id changes, e.g. after logging in again — starts over.
 */
const MAX_CONSECUTIVE_STOMP_ERRORS = 3;

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

function handleNotification(message: IMessage) {
	try {
		addNotification(JSON.parse(message.body) as Notification);
	} catch {
		// ignore malformed frames
	}
}

/**
 * Connect to the STOMP broker.
 *
 * Web auth: the backend reads the httpOnly access_token cookie from the
 * WebSocket upgrade request, so no Authorization connect header is sent
 * (JS cannot read the cookie). Mobile clients pass the JWT in the CONNECT
 * frame instead.
 *
 * No-op if a client is already active (connecting, connected or reconnecting).
 */
export function connectWS() {
	if (stompClient?.active) return;

	let consecutiveErrors = 0;
	const client = new Client({
		brokerURL: wsUrl(),
		reconnectDelay: 5000,
		onConnect: () => {
			consecutiveErrors = 0;
			client.subscribe(NOTIFICATIONS_DESTINATION, handleNotification);
			registry.forEach(attach);
		},
		onStompError: () => {
			// Unauthenticated CONNECT is rejected with an ERROR frame — don't
			// reconnect-loop forever with a dead session.
			consecutiveErrors++;
			if (consecutiveErrors >= MAX_CONSECUTIVE_STOMP_ERRORS && stompClient === client) {
				disconnectWS();
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

export function disconnectWS() {
	const client = stompClient;
	stompClient = null;
	registry.forEach((entry) => {
		entry.live = null;
	});
	void client?.deactivate();
}

// ── How-to-play progress ─────────────────────────────────────────────────────

export interface HowToPlayProgressMessage {
	status: 'generating' | 'ready' | 'error';
	progress: number;
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
