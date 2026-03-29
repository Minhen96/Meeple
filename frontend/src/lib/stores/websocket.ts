import { Client } from '@stomp/stompjs';
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
