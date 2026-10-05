import { afterEach, describe, expect, it } from 'vitest';
import { get } from 'svelte/store';
import {
	DEFAULT_LOCALE,
	detectLocale,
	errorMessage,
	getLocale,
	locale,
	m,
	normalizeLocale,
	setLocale
} from './index';
import common from './common';
import zhCommon from './zh-CN/common';

afterEach(() => setLocale(DEFAULT_LOCALE));

describe('m', () => {
	it('translates into the active locale and interpolates params', () => {
		expect(m('common.save')).toBe('Save');
		expect(m('common.greeting', { name: 'Ana' })).toBe('Hi, Ana!');

		setLocale('zh-CN');
		expect(m('common.save')).toBe('保存');
		expect(m('common.greeting', { name: 'Ana' })).toBe('你好，Ana！');
	});

	it('leaves unknown placeholders untouched', () => {
		expect(m('common.greeting')).toBe('Hi, {name}!');
	});

	it('has a zh-CN translation for every common key', () => {
		expect(Object.keys(zhCommon).sort()).toEqual(Object.keys(common).sort());
	});
});

describe('locale store', () => {
	it('publishes changes and ignores unsupported values', () => {
		setLocale('zh-CN');
		expect(get(locale)).toBe('zh-CN');
		expect(getLocale()).toBe('zh-CN');

		setLocale('fr' as never);
		expect(getLocale()).toBe('zh-CN');
	});
});

describe('detectLocale', () => {
	it('honours Accept-Language quality values', () => {
		expect(detectLocale('fr-FR,fr;q=0.9,zh-CN;q=0.8,en;q=0.7')).toBe('zh-CN');
		expect(detectLocale('en-US,en;q=0.9,zh;q=0.8')).toBe('en');
		expect(detectLocale('zh-TW;q=0.2, en-GB;q=0.5')).toBe('en');
	});

	it('accepts navigator.languages style lists and falls back to English', () => {
		expect(detectLocale(['de-DE', 'zh-Hans-CN'])).toBe('zh-CN');
		expect(detectLocale(['de-DE'])).toBe('en');
		expect(detectLocale(null)).toBe('en');
		expect(detectLocale('')).toBe('en');
	});

	it('normalizes tags', () => {
		expect(normalizeLocale('zh_CN')).toBe('zh-CN');
		expect(normalizeLocale('EN-us')).toBe('en');
		expect(normalizeLocale('ja')).toBeNull();
	});
});

describe('errorMessage', () => {
	it('maps backend codes to localized messages', () => {
		expect(errorMessage('NOT_FRIENDS')).toBe('You need to be friends to do that.');
		setLocale('zh-CN');
		expect(errorMessage('NOT_FRIENDS')).toBe('需要先成为好友才能执行此操作。');
	});

	it('falls back to the generic message', () => {
		expect(errorMessage('SOMETHING_NEW')).toBe('Something went wrong. Please try again.');
		expect(errorMessage(undefined)).toBe('Something went wrong. Please try again.');
	});
});
