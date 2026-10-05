/**
 * Share a link (FEATURES_COMPLETE 5.9): the Web Share sheet when the browser has one, otherwise
 * copy to the clipboard. The caller shows a toast for 'copied' and 'failed'; 'shared' and
 * 'cancelled' need no feedback.
 */
export type ShareOutcome = 'shared' | 'copied' | 'cancelled' | 'failed';

interface ShareEnv {
	share?: (data: ShareData) => Promise<void>;
	writeText?: (text: string) => Promise<void>;
}

function browserEnv(): ShareEnv {
	if (typeof navigator === 'undefined') return {};
	return {
		share: typeof navigator.share === 'function' ? (data) => navigator.share(data) : undefined,
		writeText: navigator.clipboard ? (text) => navigator.clipboard.writeText(text) : undefined
	};
}

export async function shareLink(
	url: string,
	title: string,
	env: ShareEnv = browserEnv()
): Promise<ShareOutcome> {
	if (env.share) {
		try {
			await env.share({ url, title });
			return 'shared';
		} catch (err) {
			// The user closed the share sheet: not an error
			if (err instanceof DOMException && err.name === 'AbortError') return 'cancelled';
			// Otherwise (NotAllowedError, unsupported data) fall back to copying
		}
	}
	if (env.writeText) {
		try {
			await env.writeText(url);
			return 'copied';
		} catch {
			return 'failed';
		}
	}
	return 'failed';
}

/** Absolute link to a post on this origin. */
export function postUrl(postId: string, origin: string): string {
	return `${origin}/posts/${postId}`;
}
