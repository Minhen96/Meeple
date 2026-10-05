/**
 * Web push configuration from build-time env (Cloudflare Pages). Push is enabled only when every
 * required VITE_FIREBASE_* value is set; otherwise every push function is a no-op.
 *
 *   VITE_FIREBASE_API_KEY, VITE_FIREBASE_PROJECT_ID, VITE_FIREBASE_MESSAGING_SENDER_ID,
 *   VITE_FIREBASE_APP_ID, VITE_FIREBASE_VAPID_KEY (required)
 *   VITE_FIREBASE_AUTH_DOMAIN (optional)
 */
export interface FirebaseWebConfig {
	apiKey: string;
	projectId: string;
	messagingSenderId: string;
	appId: string;
	authDomain?: string;
}

export interface PushConfig {
	firebase: FirebaseWebConfig;
	vapidKey: string;
}

export type PushEnv = Readonly<Record<string, string | boolean | undefined>>;

function value(env: PushEnv, key: string): string | undefined {
	const v = env[key];
	return typeof v === 'string' && v.trim() !== '' ? v.trim() : undefined;
}

/** The push config, or null when any required value is missing. */
export function readPushConfig(env: PushEnv): PushConfig | null {
	const apiKey = value(env, 'VITE_FIREBASE_API_KEY');
	const projectId = value(env, 'VITE_FIREBASE_PROJECT_ID');
	const messagingSenderId = value(env, 'VITE_FIREBASE_MESSAGING_SENDER_ID');
	const appId = value(env, 'VITE_FIREBASE_APP_ID');
	const vapidKey = value(env, 'VITE_FIREBASE_VAPID_KEY');
	if (!apiKey || !projectId || !messagingSenderId || !appId || !vapidKey) return null;
	const authDomain = value(env, 'VITE_FIREBASE_AUTH_DOMAIN');
	return {
		firebase: {
			apiKey,
			projectId,
			messagingSenderId,
			appId,
			...(authDomain ? { authDomain } : {})
		},
		vapidKey
	};
}

/**
 * Service worker URL. The worker cannot read build-time env, so the (public) Firebase web config
 * travels in its query string.
 */
export function serviceWorkerUrl(config: PushConfig): string {
	const params = new URLSearchParams({
		apiKey: config.firebase.apiKey,
		projectId: config.firebase.projectId,
		messagingSenderId: config.firebase.messagingSenderId,
		appId: config.firebase.appId
	});
	if (config.firebase.authDomain) params.set('authDomain', config.firebase.authDomain);
	return `/firebase-messaging-sw.js?${params.toString()}`;
}
