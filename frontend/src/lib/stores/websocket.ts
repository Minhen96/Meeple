import { Client, type StompSubscription } from '@stomp/stompjs';
import { addNotification } from './notifications';
import type { Notification } from '$lib/types';

const API_URL = import.meta.env.VITE_API_URL as string;

function wsUrl(): string {
	return API_URL.replace(/^http/, 'ws') + '/ws';
}

let stompClient: Client | null = null;

/**
 * Connect to the STOMP broker. Auth is handled via the access_token cookie
 * that the browser sends automatically during the WebSocket upgrade.
 * Pass accessToken explicitly only for mobile (where cookies aren't used).
 */
export function connectWS(userId: string, accessToken?: string) {
	if (stompClient?.connected) return;

	stompClient = new Client({
		brokerURL: wsUrl(),
		connectHeaders: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
		reconnectDelay: 5000,
		onConnect: () => {
			stompClient?.subscribe(`/topic/notifications/${userId}`, (message) => {
				const notification = JSON.parse(message.body) as Notification;
				addNotification(notification);
			});
		}
	});

	stompClient.activate();
}

export function disconnectWS() {
	stompClient?.deactivate();
	stompClient = null;
}

export interface HowToPlayProgressMessage {
	status: 'generating' | 'ready' | 'error';
	progress: number;
}

/**
 * Subscribe to how-to-play progress updates for a game.
 * Returns an unsubscribe function — call it in onDestroy.
 *
 * If the WS client is not yet connected the subscription is deferred until
 * the next connection (the caller should also use the REST endpoint for the
 * initial progress value on page load).
 */
export function subscribeToHowToPlayProgress(
	gameId: string,
	onMessage: (msg: HowToPlayProgressMessage) => void
): () => void {
	const topic = `/topic/how-to-play/${gameId}`;

	if (stompClient?.connected) {
		const sub: StompSubscription = stompClient.subscribe(topic, (frame) => {
			try {
				onMessage(JSON.parse(frame.body) as HowToPlayProgressMessage);
			} catch {
				// ignore malformed frames
			}
		});
		return () => sub.unsubscribe();
	}

	// WS not ready yet — attach via onConnect so we get it once connected
	const prev = stompClient?.onConnect;
	if (stompClient) {
		let sub: StompSubscription | null = null;
		stompClient.onConnect = (frame) => {
			prev?.call(stompClient, frame);
			sub = stompClient!.subscribe(topic, (f) => {
				try { onMessage(JSON.parse(f.body) as HowToPlayProgressMessage); } catch { /* ignore */ }
			});
		};
		return () => sub?.unsubscribe();
	}

	return () => {};
}
