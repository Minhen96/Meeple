// Namespace `errors.*`: user-facing messages for backend error codes (`{error, code}` responses).
// ERROR_CODE_KEYS maps a backend `code` to a message key; errorMessage() in ./index.ts uses it.
// Shared by every package: add a code here together with its message and zh-CN counterpart.
// zh-CN counterpart: ./zh-CN/errors.ts
import type { Messages } from './types';

const messages = {
	unknown: 'Something went wrong. Please try again.',
	network: "Can't reach Meeple. Check your connection and try again.",
	notFound: "We couldn't find that. It may have been removed.",
	forbidden: "You don't have permission to do that.",
	validation: 'Some details are invalid. Please check and try again.',
	rateLimited: "You're doing that too often. Please wait a moment.",
	sessionExpired: 'Your session has expired. Please sign in again.',
	accountDeleted: 'This account has been deleted.',
	userNotFound: 'This user is unavailable.',
	notFriends: 'You need to be friends to do that.',
	eventCancelled: 'This event has been cancelled.',
	eventCompleted: 'This event has already happened.',
	eventFull: 'This event is full.',
	notHost: 'Only the host can do that.',
	editWindowExpired: 'This can no longer be edited.',
	requestCooldown: 'Please wait before sending another request to this person.',
	pendingLimit: 'You have too many pending friend requests.',
	reportLimitExceeded: "You've reached today's report limit.",
	bggUserNotFound: "We couldn't find that BoardGameGeek username.",
	bggUnavailable: 'BoardGameGeek is unavailable right now. Please try again later.',
	usernameChangeTooSoon: 'You can only change your username once every 30 days.',
	usernameTaken: 'That username is taken.',
	emailTaken: 'An account with that email already exists.',
	invalidPassword: 'Incorrect password.',
	fileTooLarge: 'That file is too large.'
} as const satisfies Messages;

export default messages;

type ErrorMessageKey = `errors.${keyof typeof messages}`;

/** Backend error `code` → message key. Codes not listed fall back to `errors.unknown`. */
export const ERROR_CODE_KEYS: Readonly<Record<string, ErrorMessageKey>> = {
	UNKNOWN_ERROR: 'errors.unknown',
	INTERNAL_ERROR: 'errors.unknown',
	NETWORK_ERROR: 'errors.network',
	NOT_FOUND: 'errors.notFound',
	GAME_NOT_FOUND: 'errors.notFound',
	EVENT_NOT_FOUND: 'errors.notFound',
	POST_NOT_FOUND: 'errors.notFound',
	FORBIDDEN: 'errors.forbidden',
	BLOCKED: 'errors.userNotFound',
	VALIDATION_ERROR: 'errors.validation',
	RATE_LIMITED: 'errors.rateLimited',
	RATE_LIMIT_EXCEEDED: 'errors.rateLimited',
	TOO_MANY_REQUESTS: 'errors.rateLimited',
	SESSION_EXPIRED: 'errors.sessionExpired',
	UNAUTHORIZED: 'errors.sessionExpired',
	ACCOUNT_DELETED: 'errors.accountDeleted',
	USER_NOT_FOUND: 'errors.userNotFound',
	NOT_FRIENDS: 'errors.notFriends',
	EVENT_CANCELLED: 'errors.eventCancelled',
	EVENT_COMPLETED: 'errors.eventCompleted',
	EVENT_FULL: 'errors.eventFull',
	NOT_HOST: 'errors.notHost',
	EDIT_WINDOW_EXPIRED: 'errors.editWindowExpired',
	REQUEST_COOLDOWN: 'errors.requestCooldown',
	PENDING_LIMIT: 'errors.pendingLimit',
	REPORT_LIMIT_EXCEEDED: 'errors.reportLimitExceeded',
	BGG_USER_NOT_FOUND: 'errors.bggUserNotFound',
	BGG_API_UNAVAILABLE: 'errors.bggUnavailable',
	USERNAME_CHANGE_TOO_SOON: 'errors.usernameChangeTooSoon',
	USERNAME_TAKEN: 'errors.usernameTaken',
	EMAIL_TAKEN: 'errors.emailTaken',
	INVALID_PASSWORD: 'errors.invalidPassword',
	FILE_TOO_LARGE: 'errors.fileTooLarge'
};
