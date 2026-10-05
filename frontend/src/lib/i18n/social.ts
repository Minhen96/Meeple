// Namespace `social.*`: Feed, posts, comments, friends, search, reports. Owned by WP3 (social, feed, posts).
// Keys are flat (`'list.empty'`, `'invite.sent'`); use as m('social.<key>', params).
// Every key needs a zh-CN counterpart in ./zh-CN/social.ts.
import type { Messages } from './types';

export default {} as const satisfies Messages;
