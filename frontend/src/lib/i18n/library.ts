// Namespace `library.*`: Library, collection, plays, BGG import, AI. Owned by WP4 (library, collection, AI).
// Keys are flat (`'list.empty'`, `'invite.sent'`); use as m('library.<key>', params).
// Every key needs a zh-CN counterpart in ./zh-CN/library.ts.
import type { Messages } from './types';

export default {} as const satisfies Messages;
