// Namespace `account.*`: Auth, profile, settings, onboarding. Owned by WP5 (account, profile, settings).
// Keys are flat (`'list.empty'`, `'invite.sent'`); use as m('account.<key>', params).
// Every key needs a zh-CN counterpart in ./zh-CN/account.ts.
import type { Messages } from './types';

export default {} as const satisfies Messages;
