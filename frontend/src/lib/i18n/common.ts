// Namespace `common.*`: shared UI strings (buttons, generic states). Step 0 / WP5.
// zh-CN counterpart: ./zh-CN/common.ts
import type { Messages } from './types';

export default {
	appName: 'Meeple',
	save: 'Save',
	cancel: 'Cancel',
	delete: 'Delete',
	confirm: 'Confirm',
	retry: 'Try again',
	loading: 'Loading…',
	loadMore: 'Load more',
	empty: 'Nothing here yet',
	offline: "You're offline. Some features may be unavailable.",
	backOnline: 'Back online',
	greeting: 'Hi, {name}!'
} as const satisfies Messages;
