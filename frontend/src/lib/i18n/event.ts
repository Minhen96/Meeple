// Namespace `event.*`: Events, calendar, matching. Owned by WP2 (events, matching).
// Keys are flat (`'list.empty'`, `'invite.sent'`); use as m('event.<key>', params).
// Every key needs a zh-CN counterpart in ./zh-CN/event.ts.
import type { Messages } from './types';

export default {} as const satisfies Messages;
