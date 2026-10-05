/**
 * i18n for the web app: English (`en`) and Simplified Chinese (`zh-CN`).
 *
 * Usage:
 *   import { m } from '$lib/i18n';
 *   m('common.save')                         // "Save" / "保存"
 *   m('common.greeting', { name: 'Ana' })    // "Hi, Ana!" / "你好，Ana！"
 *   errorMessage(err.code)                   // backend error code → localized text
 *
 * Messages live in one TS dictionary per namespace, each owned by one work package
 * (docs/GAP_ANALYSIS.md section 5): `./{ns}.ts` (English, the source of truth for keys) and
 * `./zh-CN/{ns}.ts`. Keys are type-checked: `m('common.nope')` fails svelte-check.
 *
 * Locale resolution: the `lang` cookie, else the browser's Accept-Language (hooks.server.ts),
 * passed to the root layout as `data.locale`. `setLocale(l, { persist: true })` writes the
 * cookie. The account package syncs it with the user's preferredLanguage.
 *
 * `m()` is a plain function, not reactive by itself: the root layout re-renders the page
 * (`{#key $locale}`) when the locale changes. Do not call `m()` in load functions; return
 * keys or data and translate in components.
 */
import { writable, type Readable } from 'svelte/store';
import type { MessageParams, Messages } from './types';
import common from './common';
import notif from './notif';
import event from './event';
import social from './social';
import library from './library';
import account from './account';
import errors, { ERROR_CODE_KEYS } from './errors';
import zhCommon from './zh-CN/common';
import zhNotif from './zh-CN/notif';
import zhEvent from './zh-CN/event';
import zhSocial from './zh-CN/social';
import zhLibrary from './zh-CN/library';
import zhAccount from './zh-CN/account';
import zhErrors from './zh-CN/errors';

export type { MessageParams } from './types';

export const LOCALES = ['en', 'zh-CN'] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'en';
/** Cookie holding the chosen locale; readable by the server for SSR. */
export const LOCALE_COOKIE = 'lang';
const LOCALE_COOKIE_MAX_AGE_S = 60 * 60 * 24 * 365;

const en = { common, notif, event, social, library, account, errors };

type Namespaces = typeof en;
type Namespace = keyof Namespaces;

/** Every valid message key, `'{namespace}.{key}'`. */
export type MessageKey = {
	[N in Namespace]: `${N}.${Extract<keyof Namespaces[N], string>}`;
}[Namespace];

const catalogs: Record<Locale, Record<Namespace, Messages>> = {
	en,
	'zh-CN': {
		common: zhCommon,
		notif: zhNotif,
		event: zhEvent,
		social: zhSocial,
		library: zhLibrary,
		account: zhAccount,
		errors: zhErrors
	}
};

// ─── Locale state ─────────────────────────────────────────────────────────

let current: Locale = DEFAULT_LOCALE;
const localeStore = writable<Locale>(DEFAULT_LOCALE);

/** The active locale. Subscribe with `$locale`; change it with `setLocale`. */
export const locale: Readable<Locale> = { subscribe: localeStore.subscribe };

export function getLocale(): Locale {
	return current;
}

export function isLocale(value: unknown): value is Locale {
	return typeof value === 'string' && (LOCALES as readonly string[]).includes(value);
}

/**
 * Switch the active locale. With `persist`, also store it in the `lang` cookie (browser only)
 * so the server renders the next request in it.
 */
export function setLocale(next: Locale, options: { persist?: boolean } = {}): void {
	if (!isLocale(next)) return;
	if (next !== current) {
		current = next;
		localeStore.set(next);
	}
	if (typeof document !== 'undefined') {
		document.documentElement.lang = next;
		if (options.persist) {
			document.cookie = `${LOCALE_COOKIE}=${encodeURIComponent(next)}; Path=/; Max-Age=${LOCALE_COOKIE_MAX_AGE_S}; SameSite=Lax`;
		}
	}
}

/** Map a BCP 47 tag to a supported locale: any `zh*` → zh-CN, any `en*` → en, else null. */
export function normalizeLocale(tag: string | null | undefined): Locale | null {
	if (!tag) return null;
	const lower = tag.trim().toLowerCase();
	if (lower === 'zh' || lower.startsWith('zh-') || lower.startsWith('zh_')) return 'zh-CN';
	if (lower === 'en' || lower.startsWith('en-') || lower.startsWith('en_')) return 'en';
	return null;
}

/**
 * Pick the best supported locale from an Accept-Language header value or a list of tags in
 * preference order (for example `navigator.languages`). Falls back to `DEFAULT_LOCALE`.
 */
export function detectLocale(input: string | readonly string[] | null | undefined): Locale {
	if (!input) return DEFAULT_LOCALE;
	const tags =
		typeof input === 'string'
			? input
					.split(',')
					.map((part, index) => {
						const [tag, ...params] = part.trim().split(';');
						const q = params.map((p) => p.trim()).find((p) => p.startsWith('q='));
						const quality = q ? Number.parseFloat(q.slice(2)) : 1;
						return { tag, quality: Number.isNaN(quality) ? 0 : quality, index };
					})
					.filter((t) => t.tag && t.quality > 0)
					.sort((a, b) => b.quality - a.quality || a.index - b.index)
					.map((t) => t.tag)
			: input;
	for (const tag of tags) {
		const match = normalizeLocale(tag);
		if (match) return match;
	}
	return DEFAULT_LOCALE;
}

// ─── Messages ─────────────────────────────────────────────────────────────

function interpolate(template: string, params?: MessageParams): string {
	if (!params) return template;
	return template.replace(/\{(\w+)\}/g, (whole, name: string) =>
		Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : whole
	);
}

/**
 * Translate `key` ('{namespace}.{key}') into the active locale, filling `{param}` placeholders.
 * Falls back to English, then to the key itself.
 */
export function m(key: MessageKey, params?: MessageParams): string {
	const dot = key.indexOf('.');
	const ns = key.slice(0, dot) as Namespace;
	const name = key.slice(dot + 1);
	const template = catalogs[current][ns]?.[name] ?? catalogs.en[ns]?.[name] ?? key;
	return interpolate(template, params);
}

/** Localized message for a backend error `code`; unknown codes give the generic message. */
export function errorMessage(code: string | null | undefined): string {
	return m((code && ERROR_CODE_KEYS[code]) || 'errors.unknown');
}
