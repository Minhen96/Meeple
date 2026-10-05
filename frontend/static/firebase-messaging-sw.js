/* global firebase */
/**
 * Background web push (Firebase Cloud Messaging). Registered by src/lib/push/fcm.ts only when
 * the VITE_FIREBASE_* config is set; the public web config arrives in this script's query
 * string because a service worker cannot read build-time env.
 *
 * Messages carry a `notification` block, which the SDK displays itself. Clicks are handled
 * here (registered before the SDK loads, so this listener runs first): the app opens, or an open
 * tab navigates, to the in-app `data.path` of the notification.
 */

const FIREBASE_VERSION = '10.14.1';

function safePath(path) {
	return typeof path === 'string' &&
		path.startsWith('/') &&
		!path.startsWith('//') &&
		!path.includes('\\')
		? path
		: '/notifications';
}

function pathOf(notification) {
	const data = notification && notification.data ? notification.data : {};
	// The SDK stores the original message under FCM_MSG for notifications it displayed
	const payload = data.FCM_MSG && data.FCM_MSG.data ? data.FCM_MSG.data : data;
	return safePath(payload.path);
}

self.addEventListener('notificationclick', (event) => {
	event.notification.close();
	const target = new URL(pathOf(event.notification), self.location.origin).href;
	event.stopImmediatePropagation();
	event.waitUntil(
		self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
			for (const client of windows) {
				if (client.url.startsWith(self.location.origin) && 'focus' in client) {
					return client
						.focus()
						.then((focused) =>
							focused && 'navigate' in focused ? focused.navigate(target) : focused
						);
				}
			}
			return self.clients.openWindow(target);
		})
	);
});

const params = new URL(self.location.href).searchParams;
const config = {
	apiKey: params.get('apiKey'),
	projectId: params.get('projectId'),
	messagingSenderId: params.get('messagingSenderId'),
	appId: params.get('appId')
};
if (params.get('authDomain')) config.authDomain = params.get('authDomain');

if (config.apiKey && config.projectId && config.messagingSenderId && config.appId) {
	importScripts(
		`https://www.gstatic.com/firebasejs/${FIREBASE_VERSION}/firebase-app-compat.js`,
		`https://www.gstatic.com/firebasejs/${FIREBASE_VERSION}/firebase-messaging-compat.js`
	);
	firebase.initializeApp(config);
	// Initialising messaging installs the SDK's push handler (displays the notification block)
	firebase.messaging();
}
