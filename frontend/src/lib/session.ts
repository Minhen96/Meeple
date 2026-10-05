import { setUser } from '$lib/stores/auth';
import { disconnectWS } from '$lib/stores/websocket';

const AI_CHAT_PREFIX = 'ai_chat_';

/** localStorage key for a user's AI chat history with a given game. */
export function aiChatStorageKey(userId: string, gameId: string): string {
	return `${AI_CHAT_PREFIX}${userId}_${gameId}`;
}

/** Remove every persisted AI chat history (all users, all games). */
export function clearAiChatHistory() {
	try {
		const keys: string[] = [];
		for (let i = 0; i < localStorage.length; i++) {
			const key = localStorage.key(i);
			if (key?.startsWith(AI_CHAT_PREFIX)) keys.push(key);
		}
		keys.forEach((key) => localStorage.removeItem(key));
	} catch {
		// storage unavailable (SSR, private mode, blocked) — nothing to clear
	}
}

/**
 * Tear down all client-side session state: user store, WebSocket connection
 * and per-user local caches. Call on logout, account deletion and when the
 * session can no longer be refreshed.
 */
export function clearClientSession() {
	setUser(null);
	disconnectWS();
	clearAiChatHistory();
}
