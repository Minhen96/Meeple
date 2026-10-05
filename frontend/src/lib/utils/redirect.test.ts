import { describe, expect, it } from 'vitest';
import { safeRedirectPath } from './redirect';

describe('safeRedirectPath', () => {
	it.each(['/', '/library', '/events/123?tab=mine#top', '/profile/abc/'])(
		'accepts same-origin path %s',
		(path) => {
			expect(safeRedirectPath(path)).toBe(path);
		}
	);

	it.each([
		null,
		undefined,
		'',
		'library',
		'//evil.com',
		'//evil.com/path',
		'/\\evil.com',
		'https://evil.com',
		'javascript:alert(1)',
		'/\t/evil.com',
		'/\n/evil.com',
		' /library'
	])('rejects %j', (path) => {
		expect(safeRedirectPath(path)).toBe('/');
	});

	it('uses the given fallback', () => {
		expect(safeRedirectPath('//evil.com', '/home')).toBe('/home');
	});
});
