import { describe, expect, it } from 'vitest';
import type { Messages } from './types';
import common from './common';
import notif from './notif';
import event from './event';
import social from './social';
import library from './library';
import account from './account';
import admin from './admin';
import errors from './errors';
import zhCommon from './zh-CN/common';
import zhNotif from './zh-CN/notif';
import zhEvent from './zh-CN/event';
import zhSocial from './zh-CN/social';
import zhLibrary from './zh-CN/library';
import zhAccount from './zh-CN/account';
import zhAdmin from './zh-CN/admin';
import zhErrors from './zh-CN/errors';

const NAMESPACES: Record<string, [Messages, Messages]> = {
	common: [common, zhCommon],
	notif: [notif, zhNotif],
	event: [event, zhEvent],
	social: [social, zhSocial],
	library: [library, zhLibrary],
	account: [account, zhAccount],
	admin: [admin, zhAdmin],
	errors: [errors, zhErrors]
};

const placeholders = (text: string) => [...text.matchAll(/\{(\w+)\}/g)].map((p) => p[1]).sort();

describe('message catalogs', () => {
	it.each(Object.entries(NAMESPACES))('%s: en and zh-CN have the same keys', (_ns, [en, zh]) => {
		expect(Object.keys(zh).sort()).toEqual(Object.keys(en).sort());
	});

	it.each(Object.entries(NAMESPACES))(
		'%s: translations keep every {placeholder}',
		(_ns, [en, zh]) => {
			for (const [key, text] of Object.entries(en)) {
				expect({ key, params: placeholders(zh[key] ?? '') }).toEqual({
					key,
					params: placeholders(text)
				});
			}
		}
	);

	it.each(Object.entries(NAMESPACES))('%s: no empty messages', (_ns, [en, zh]) => {
		for (const [key, text] of [...Object.entries(en), ...Object.entries(zh)]) {
			expect({ key, empty: text.trim() === '' }).toEqual({
				key,
				empty: false
			});
		}
	});
});
