// @vitest-environment jsdom
import { get } from 'svelte/store';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const m = vi.hoisted(() => ({
	logout: vi.fn(async () => {}),
	unregister: vi.fn(async () => {}),
	identifyUser: vi.fn(),
	disconnectWS: vi.fn()
}));
vi.mock('$lib/api/auth', () => ({ authApi: { logout: m.logout } }));
vi.mock('$lib/push', () => ({ pushApi: { unregister: m.unregister } }));
vi.mock('$lib/observability', () => ({ identifyUser: m.identifyUser }));
vi.mock('$lib/stores/websocket', () => ({ disconnectWS: m.disconnectWS }));

const { aiChatStorageKey, clearAiChatHistory, clearClientSession, logout } = await import('./session');
const { currentUser, setUser } = await import('$lib/stores/auth');

beforeEach(() => {
	localStorage.clear();
	for (const fn of Object.values(m)) fn.mockReset();
	m.unregister.mockResolvedValue(undefined);
	setUser({ id: 'u1', username: 'u1' } as never);
});

describe('AI chat history', () => {
	it('keys history by user and game', () => {
		expect(aiChatStorageKey('u1', 'g1')).toBe('ai_chat_u1_g1');
	});

	it('clears every ai_chat_* entry and nothing else', () => {
		localStorage.setItem(aiChatStorageKey('u1', 'g1'), '[]');
		localStorage.setItem(aiChatStorageKey('u2', 'g2'), '[]');
		localStorage.setItem('people_search_history_u1', '[]');
		clearAiChatHistory();
		expect(localStorage.length).toBe(1);
		expect(localStorage.getItem('people_search_history_u1')).toBe('[]');
	});

	it('tolerates unavailable storage', () => {
		vi.spyOn(Storage.prototype, 'key').mockImplementationOnce(() => {
			throw new Error('blocked');
		});
		localStorage.setItem('ai_chat_x', '1');
		expect(() => clearAiChatHistory()).not.toThrow();
	});
});

describe('clearClientSession', () => {
	it('clears the user, observability identity, websocket and AI caches', () => {
		localStorage.setItem('ai_chat_u1_g1', '[]');
		clearClientSession();
		expect(get(currentUser)).toBeNull();
		expect(m.identifyUser).toHaveBeenCalledWith(null);
		expect(m.disconnectWS).toHaveBeenCalled();
		expect(localStorage.getItem('ai_chat_u1_g1')).toBeNull();
	});

	it('unregisters push fire-and-forget: never awaited, failures swallowed', async () => {
		let settle: (() => void) | undefined;
		m.unregister.mockImplementation(() => new Promise<void>((resolve) => (settle = resolve)));
		clearClientSession();
		expect(m.unregister).toHaveBeenCalledTimes(1);
		// the rest of the teardown ran synchronously while unregister is still pending
		expect(get(currentUser)).toBeNull();
		expect(m.disconnectWS).toHaveBeenCalled();
		settle?.();

		m.unregister.mockRejectedValueOnce(new Error('401'));
		expect(() => clearClientSession()).not.toThrow();
		await Promise.resolve();
	});
});

describe('logout', () => {
	it('unregisters push before ending the server session, then clears local state', async () => {
		const order: string[] = [];
		m.unregister.mockImplementation(async () => {
			order.push('push');
		});
		m.logout.mockImplementation(async () => {
			order.push('logout');
		});
		await logout();
		// the trailing 'push' is clearClientSession's best-effort call (a no-op once the token is gone)
		expect(order).toEqual(['push', 'logout', 'push']);
		expect(get(currentUser)).toBeNull();
	});

	it('never blocks on server failures', async () => {
		m.unregister.mockRejectedValue(new Error('push'));
		m.logout.mockRejectedValue(new Error('net'));
		await expect(logout()).resolves.toBeUndefined();
		expect(get(currentUser)).toBeNull();
		expect(m.disconnectWS).toHaveBeenCalled();
	});
});
