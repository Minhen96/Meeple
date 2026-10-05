import { afterEach, describe, expect, it } from 'vitest';
import { formatNumber, formatPercent } from './format';
import { setLocale } from './index';

afterEach(() => {
	setLocale('en');
});

describe('i18n number formatting', () => {
	it('formats numbers in the active locale', () => {
		expect(formatNumber(1234567)).toBe('1,234,567');
		expect(formatNumber(1.5, { minimumFractionDigits: 2 })).toBe('1.50');
		setLocale('zh-CN');
		expect(formatNumber(1234)).toBe(new Intl.NumberFormat('zh-CN').format(1234));
	});

	it('formats 0-100 progress values as whole percentages', () => {
		expect(formatPercent(45)).toBe('45%');
		expect(formatPercent(12.6)).toBe('13%');
		expect(formatPercent(100)).toBe('100%');
	});
});
