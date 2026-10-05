// @vitest-environment jsdom
// WebSocket store against a fake STOMP client: lifecycle, topic registry across reconnects,
// error back-off, session handling and badge resync.
import { get } from 'svelte/store';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

interface FakeSub {
	destination: string;
	callback: (m: { body: string }) => void;
	unsubscribe: ReturnType<typeof vi.fn>;
}

interface FakeConfig {
	brokerURL: string;
	reconnectDelay: number;
	beforeConnect: () => Promise<void>;
	onConnect: () => void;
	onStompError: () => void;
	onWebSocketClose: () => void;
}

const h = vi.hoisted(() => {
	class FakeClient {
		static instances: FakeClient[] = [];
		active = false;
		connected = false;
		subs: FakeSub[] = [];
		activate = vi.fn(() => {
			this.active = true;
		});
		deactivate = vi.fn(async () => {
			this.active = false;
			this.connected = false;
		});
		constructor(public config: FakeConfig) {
			FakeClient.instances.push(this);
		}
		subscribe(destination: string, callback: FakeSub['callback']) {
			const sub: FakeSub = { destination, callback, unsubscribe: vi.fn() };
			this.subs.push(sub);
			return sub;
		}
		/** Simulate the broker accepting the CONNECT. */
		connect() {
			this.connected = true;
			this.config.onConnect();
		}
		/** Simulate the socket dropping. */
		drop() {
			this.connected = false;
			this.config.onWebSocketClose();
		}
	}
	return {
		FakeClient,
		ensureSession: vi.fn(async () => 'ok' as 'ok' | 'expired' | 'unavailable'),
		refreshListeners: [] as Array<() => void>,
		getUnreadCount: vi.fn(async () => 4)
	};
});

vi.mock('@stomp/stompjs', () => ({ Client: h.FakeClient }));
vi.mock('$lib/api/client', () => ({
	ensureSession: h.ensureSession,
	onSessionRefreshed: (fn: () => void) => {
		h.refreshListeners.push(fn);
		return () => {};
	}
}));
vi.mock('$lib/api/notifications', () => ({ notificationsApi: { getUnreadCount: h.getUnreadCount } }));
vi.stubEnv('VITE_API_URL', 'https://api.meeple.test');

type WsModule = typeof import('./websocket');
type NotifModule = typeof import('./notifications');
let ws: WsModule;
let notif: NotifModule;

const clients = () => h.FakeClient.instances;
const latest = () => {
	const c = clients().at(-1);
	if (!c) throw new Error('no client');
	return c;
};
const flush = () => new Promise((r) => setTimeout(r, 0));

beforeEach(async () => {
	vi.resetModules();
	h.FakeClient.instances = [];
	h.refreshListeners.length = 0;
	h.ensureSession.mockReset().mockResolvedValue('ok');
	h.getUnreadCount.mockReset().mockResolvedValue(4);
	ws = await import('./websocket');
	notif = await import('./notifications');
	// Re-importing fresh module graphs can be slow on a loaded CI runner with coverage on.
}, 30_000);

// Each test gets a fresh module instance; remove the previous one's window/document listeners.
afterEach(() => {
	ws?.disconnectWS();
});

describe('connectWS / disconnectWS', () => {
	it('activates one client on the ws:// broker URL and is idempotent while active', () => {
		ws.connectWS();
		ws.connectWS();
		expect(clients()).toHaveLength(1);
		expect(latest().config.brokerURL).toBe('wss://api.meeple.test/ws');
		expect(latest().config.reconnectDelay).toBe(5000);
		expect(latest().activate).toHaveBeenCalledTimes(1);
	});

	it('on connect subscribes to the user notification queue and resyncs the unread badge', async () => {
		ws.connectWS();
		latest().connect();
		expect(latest().subs.map((s) => s.destination)).toEqual(['/user/queue/notifications']);
		await flush();
		expect(get(notif.unreadCount)).toBe(4);
	});

	it('keeps the last badge value when the resync fails', async () => {
		notif.setUnreadCount(9);
		h.getUnreadCount.mockRejectedValue(new Error('offline'));
		ws.connectWS();
		latest().connect();
		await flush();
		expect(get(notif.unreadCount)).toBe(9);
	});

	it('routes notification frames into the store and ignores malformed ones', () => {
		ws.connectWS();
		latest().connect();
		const queue = latest().subs[0];
		queue.callback({ body: 'not json' });
		expect(get(notif.notifications)).toEqual([]);
		queue.callback({
			body: JSON.stringify({
				notification: { id: 'n1', type: 'POST_LIKED', createdAt: '2026-01-01T00:00:00Z', read: false },
				unreadCount: 3
			})
		});
		expect(get(notif.notifications).map((n) => n.id)).toEqual(['n1']);
		expect(get(notif.unreadCount)).toBe(3);
	});

	it('disconnect deactivates the client, resets notifications and stops reconnecting', () => {
		ws.connectWS();
		notif.setUnreadCount(5);
		const client = latest();
		ws.disconnectWS();
		expect(client.deactivate).toHaveBeenCalled();
		expect(get(notif.unreadCount)).toBeNull();
		ws.reconnectWS();
		expect(clients()).toHaveLength(1);
	});

	it('disconnect without a client is safe', () => {
		expect(() => ws.disconnectWS()).not.toThrow();
	});
});

describe('beforeConnect session check', () => {
	it('refreshes the session before each attempt and stays connected when ok', async () => {
		ws.connectWS();
		await latest().config.beforeConnect();
		expect(h.ensureSession).toHaveBeenCalled();
		expect(latest().deactivate).not.toHaveBeenCalled();
	});

	it('an expired session disconnects', async () => {
		h.ensureSession.mockResolvedValue('expired');
		ws.connectWS();
		const client = latest();
		await client.config.beforeConnect();
		expect(client.deactivate).toHaveBeenCalled();
	});

	it('an expired session for a stale client does not touch the current one', async () => {
		ws.connectWS();
		const stale = latest();
		ws.disconnectWS();
		ws.connectWS();
		const current = latest();
		h.ensureSession.mockResolvedValue('expired');
		await stale.config.beforeConnect();
		expect(current.deactivate).not.toHaveBeenCalled();
	});
});

describe('topic registry', () => {
	it('subscriptions made before connecting attach on connect and re-attach after a drop', () => {
		const cb = vi.fn();
		ws.subscribeTopic('/topic/x', cb);
		ws.connectWS();
		const client = latest();
		client.connect();
		expect(client.subs.filter((s) => s.destination === '/topic/x')).toHaveLength(1);

		client.drop();
		client.connect();
		expect(client.subs.filter((s) => s.destination === '/topic/x')).toHaveLength(2);
		client.subs.at(-1)?.callback({ body: 'hi' });
		expect(cb).toHaveBeenCalledWith({ body: 'hi' });
	});

	it('subscribing while connected attaches immediately; unsubscribe detaches once', () => {
		ws.connectWS();
		latest().connect();
		const off = ws.subscribeTopic('/topic/y', vi.fn());
		const sub = latest().subs.find((s) => s.destination === '/topic/y');
		expect(sub).toBeDefined();
		off();
		off();
		expect(sub?.unsubscribe).toHaveBeenCalledTimes(1);
		latest().drop();
		latest().connect();
		expect(latest().subs.filter((s) => s.destination === '/topic/y')).toHaveLength(1);
	});

	it('unsubscribe survives a connection that died mid-call', () => {
		ws.connectWS();
		latest().connect();
		const off = ws.subscribeTopic('/topic/z', vi.fn());
		latest().subs.at(-1)?.unsubscribe.mockImplementation(() => {
			throw new Error('socket closed');
		});
		expect(() => off()).not.toThrow();
	});

	it('unsubscribe while disconnected does not call the dead subscription', () => {
		ws.connectWS();
		latest().connect();
		const off = ws.subscribeTopic('/topic/q', vi.fn());
		const sub = latest().subs.at(-1);
		latest().connected = false;
		off();
		expect(sub?.unsubscribe).not.toHaveBeenCalled();
	});
});

describe('error back-off and resume', () => {
	it('pauses after 3 consecutive STOMP errors', () => {
		ws.connectWS();
		const client = latest();
		client.config.onStompError();
		client.config.onStompError();
		expect(client.deactivate).not.toHaveBeenCalled();
		client.config.onStompError();
		expect(client.deactivate).toHaveBeenCalled();
	});

	it('a successful connect resets the error streak', () => {
		ws.connectWS();
		const client = latest();
		client.config.onStompError();
		client.config.onStompError();
		client.connect();
		client.config.onStompError();
		client.config.onStompError();
		expect(client.deactivate).not.toHaveBeenCalled();
	});

	it('resumes on token refresh, on tab visible and on online', () => {
		ws.connectWS();
		const pause = () => {
			const c = latest();
			c.config.onStompError();
			c.config.onStompError();
			c.config.onStompError();
		};
		pause();
		expect(h.refreshListeners).toHaveLength(1);
		h.refreshListeners[0]();
		expect(clients()).toHaveLength(2);

		pause();
		Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
		document.dispatchEvent(new Event('visibilitychange'));
		expect(clients()).toHaveLength(2);
		Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
		document.dispatchEvent(new Event('visibilitychange'));
		expect(clients()).toHaveLength(3);

		pause();
		window.dispatchEvent(new Event('online'));
		expect(clients()).toHaveLength(4);
	});

	it('reconnect is a no-op while a client is active, and listeners are removed on disconnect', () => {
		ws.connectWS();
		ws.reconnectWS();
		expect(clients()).toHaveLength(1);
		ws.disconnectWS();
		window.dispatchEvent(new Event('online'));
		expect(clients()).toHaveLength(1);
	});

	it('registers the session-refresh listener only once', () => {
		ws.connectWS();
		ws.disconnectWS();
		ws.connectWS();
		expect(h.refreshListeners).toHaveLength(1);
	});
});

describe('subscribeToHowToPlayProgress', () => {
	it('parses progress frames for the game topic and ignores malformed frames', () => {
		const onMessage = vi.fn();
		ws.connectWS();
		latest().connect();
		const off = ws.subscribeToHowToPlayProgress('g1', onMessage);
		const sub = latest().subs.find((s) => s.destination === '/topic/how-to-play/g1');
		sub?.callback({ body: '{bad' });
		sub?.callback({ body: JSON.stringify({ status: 'generating', progress: 40 }) });
		expect(onMessage).toHaveBeenCalledTimes(1);
		expect(onMessage).toHaveBeenCalledWith({ status: 'generating', progress: 40 });
		off();
		expect(sub?.unsubscribe).toHaveBeenCalled();
	});
});
