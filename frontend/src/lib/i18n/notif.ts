// Namespace `notif.*`: Notifications, preferences, push. Owned by WP1 (notifications).
// Keys are flat (`'list.empty'`, `'invite.sent'`); use as m('notif.<key>', params).
// Every key needs a zh-CN counterpart in ./zh-CN/notif.ts.
import type { Messages } from './types';

export default {} as const satisfies Messages;
