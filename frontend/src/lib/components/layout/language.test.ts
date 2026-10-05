import { afterEach, describe, expect, it, vi } from 'vitest';
import { getLocale, m, setLocale } from '$lib/i18n';
import type { User } from '$lib/types';
import { LANGUAGE_NAMES, changeLanguage } from './language';

const user = { id: 'u1', preferredLanguage: 'zh-CN' } as User;

describe('changeLanguage', () => {
	afterEach(() => setLocale('en'));

	it('switches the UI and saves the account language', async () => {
		const save = vi.fn().mockResolvedValue(user);
		const onSaved = vi.fn();

		await changeLanguage('zh-CN', { save, onSaved });

		expect(getLocale()).toBe('zh-CN');
		expect(save).toHaveBeenCalledWith('zh-CN');
		expect(onSaved).toHaveBeenCalledWith(user);
		expect(m('common.save')).toBe('保存');
	});

	it('does nothing when the language is unchanged', async () => {
		const save = vi.fn();
		await changeLanguage('en', { save });
		expect(save).not.toHaveBeenCalled();
	});

	it('rolls back when saving fails', async () => {
		const save = vi.fn().mockRejectedValue(new Error('offline'));
		await expect(changeLanguage('zh-CN', { save })).rejects.toThrow('offline');
		expect(getLocale()).toBe('en');
	});

	it('rejects unsupported locales', async () => {
		// @ts-expect-error deliberately invalid
		await expect(changeLanguage('fr', { save: vi.fn() })).rejects.toThrow('Unsupported');
	});

	it('names each language in itself', () => {
		expect(LANGUAGE_NAMES['zh-CN']).toBe('中文');
		expect(LANGUAGE_NAMES.en).toBe('English');
	});
});
