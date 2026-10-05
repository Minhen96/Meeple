/** One namespace's English messages: flat `key → text`; `{name}` marks a parameter. */
export type Messages = Readonly<Record<string, string>>;

/**
 * The zh-CN counterpart of an English namespace: every English key must be translated
 * (svelte-check fails on a missing key). Untranslated keys at runtime fall back to English.
 */
export type Translation<T extends Messages> = {
	readonly [K in keyof T]: string;
};

export type MessageParams = Readonly<Record<string, string | number>>;
