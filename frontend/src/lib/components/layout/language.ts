import { getLocale, isLocale, setLocale, type Locale } from '$lib/i18n';
import type { User } from '$lib/types';

export interface LanguageDeps {
	/** Persists the choice on the account (PUT /users/me); returns the updated user. */
	save: (locale: Locale) => Promise<User>;
	/** Receives the updated user (e.g. the current-user store). */
	onSaved?: (user: User) => void;
}

/**
 * Switch the UI language: applied at once and stored in the `lang` cookie (SSR), then saved as
 * the account's preferredLanguage. If saving fails the previous language is restored and the
 * error rethrown, so the UI never disagrees with the account.
 */
export async function changeLanguage(next: Locale, deps: LanguageDeps): Promise<void> {
	if (!isLocale(next)) throw new Error(`Unsupported locale: ${String(next)}`);
	const previous = getLocale();
	if (previous === next) return;
	setLocale(next, { persist: true });
	try {
		const user = await deps.save(next);
		deps.onSaved?.(user);
	} catch (err) {
		setLocale(previous, { persist: true });
		throw err;
	}
}

/** Language names shown in the switcher, each in its own language. */
export const LANGUAGE_NAMES: Record<Locale, string> = {
	en: 'English',
	'zh-CN': '中文'
};
