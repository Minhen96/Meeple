import { Client } from '@stomp/stompjs';
import { addNotification } from './notifications';
import type { Notification } from '$lib/types';

const WS_URL = import.meta.env.VITE_WS_URL as string;

let stompClient: Client | null = null;

export function connectWS(accessToken: string) {
	if (stompClient?.connected) return;

	stompClient = new Client({
		brokerURL: WS_URL,
		connectHeaders: { Authorization: `Bearer ${accessToken}` },
		reconnectDelay: 5000,
		onConnect: () => {
			stompClient?.subscribe('/user/queue/notifications', (message) => {
				const notification = JSON.parse(message.body) as Notification;
				addNotification(notification);
			});
		},
		onDisconnect: () => {
			// Will auto-reconnect via reconnectDelay
		}
	});

	stompClient.activate();
}

export function disconnectWS() {
	stompClient?.deactivate();
	stompClient = null;
}
