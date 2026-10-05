// Namespace `notif.*`: Notifications, preferences, push. Owned by WP1 (notifications).
// Keys are flat (`'list.empty'`, `'invite.sent'`); use as m('notif.<key>', params).
// Every key needs a zh-CN counterpart in ./zh-CN/notif.ts.
import type { Messages } from './types';

export default {
	// Notification centre
	'page.title': 'Notifications',
	'page.back': 'Back',
	'page.markAllRead': 'Mark all read',
	'group.today': 'Today',
	'group.thisWeek': 'This Week',
	'group.earlier': 'Earlier',
	'empty.title': "You're all caught up!",
	'empty.body': 'Notifications will appear here.',
	'item.unread': 'Unread',
	'item.markRead': 'Mark as read',
	'item.delete': 'Delete',
	'item.deletedUser': 'Deleted User',
	'list.loadFailed': "Couldn't load notifications.",
	'list.retry': 'Try again',
	'list.loadingMore': 'Loading more…',
	'action.failed': "Couldn't update the notification. Please try again.",
	'time.justNow': 'just now',
	'time.minutes': '{n}m',
	'time.hours': '{n}h',
	'time.days': '{n}d',

	// Preferences
	'prefs.title': 'Notification Preferences',
	'prefs.intro': 'Choose what reaches you in the app and as push notifications.',
	'prefs.type': 'Type',
	'prefs.inApp': 'In-App',
	'prefs.push': 'Push',
	'prefs.loadFailed': "Couldn't load your notification settings.",
	'prefs.saveFailed': "Couldn't save. Please try again.",
	'prefs.saved': 'Saved',
	'prefs.category.eventInvites': 'Event Invites',
	'prefs.category.eventUpdates': 'Event Updates',
	'prefs.category.eventReminders': 'Event Reminders',
	'prefs.category.matchFound': 'Match Found',
	'prefs.category.friendRequests': 'Friend Requests',
	'prefs.category.postLiked': 'Post Liked',
	'prefs.category.postComment': 'Post Comment',
	'prefs.category.commentMention': 'Comment Mention',
	'prefs.category.postTagged': 'Post Tagged',
	'prefs.category.library': 'Library & Rules',
	'prefs.toggle': '{category}: {channel}',

	// Quiet hours
	'quiet.title': 'Do Not Disturb',
	'quiet.description': 'Push notifications paused during quiet hours',
	'quiet.start': 'From',
	'quiet.end': 'To',
	'quiet.timezone': 'Time zone: {zone}',
	'quiet.sameTime': 'Start and end must be different times.',

	// Web push
	'push.title': 'Push on this browser',
	'push.enabled': 'This browser receives push notifications when Meeple is closed.',
	'push.disabled': 'Get notified on this browser when Meeple is closed.',
	'push.denied': 'Notifications are blocked for this site. Allow them in your browser settings.',
	'push.unsupported': "This browser doesn't support push notifications.",
	'push.enable': 'Turn on',
	'push.disable': 'Turn off'
} as const satisfies Messages;
