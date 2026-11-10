import { describe, expect, it } from 'vitest';
import { isActiveSettingsHref, isSettingsRoot } from './settingsNav';

describe('isSettingsRoot', () => {
	it('matches the settings menu with or without a trailing slash', () => {
		expect(isSettingsRoot('/settings')).toBe(true);
		expect(isSettingsRoot('/settings/')).toBe(true);
	});

	it('does not match sub-screens or other routes', () => {
		expect(isSettingsRoot('/settings/profile')).toBe(false);
		expect(isSettingsRoot('/settingsx')).toBe(false);
		expect(isSettingsRoot('/')).toBe(false);
	});
});

describe('isActiveSettingsHref', () => {
	it('marks the row for the screen being shown', () => {
		expect(isActiveSettingsHref('/settings/profile', '/settings/profile')).toBe(true);
		expect(isActiveSettingsHref('/settings/profile/', '/settings/profile')).toBe(true);
		expect(isActiveSettingsHref('/settings/sessions/abc', '/settings/sessions')).toBe(true);
	});

	it('leaves other rows inactive', () => {
		expect(isActiveSettingsHref('/settings/profile', '/settings/password')).toBe(false);
		expect(isActiveSettingsHref('/settings', '/settings/profile')).toBe(false);
		expect(isActiveSettingsHref('/settings/profiles', '/settings/profile')).toBe(false);
	});

	it('never marks hash links, links outside settings or rows without a link', () => {
		expect(isActiveSettingsHref('/settings/notifications', '/settings/notifications#quiet-hours')).toBe(false);
		expect(isActiveSettingsHref('/admin/health', '/admin/health')).toBe(false);
		expect(isActiveSettingsHref('/settings/profile', 'https://example.com/terms')).toBe(false);
		expect(isActiveSettingsHref('/settings/profile', undefined)).toBe(false);
	});
});
