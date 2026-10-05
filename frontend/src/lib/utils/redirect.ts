const PROBE_ORIGIN = 'http://same-origin.invalid';

/**
 * Return `target` if it is a safe same-origin relative path to navigate to
 * after login, otherwise `fallback`. Blocks open redirects such as
 * `//evil.com`, `/\evil.com`, absolute URLs, `javascript:` and paths with
 * control characters (browsers strip tab/newline, turning `/\t/evil.com`
 * into `//evil.com`).
 */
export function safeRedirectPath(target: string | null | undefined, fallback = '/'): string {
	if (!target || !target.startsWith('/')) return fallback;
	if (target.startsWith('//') || target.startsWith('/\\')) return fallback;
	// eslint-disable-next-line no-control-regex -- deliberately matching control characters
	if (/[\u0000-\u001f\u007f]/.test(target)) return fallback;
	try {
		// Belt and braces: whatever the browser would resolve it to must stay on our origin.
		if (new URL(target, PROBE_ORIGIN).origin !== PROBE_ORIGIN) return fallback;
	} catch {
		return fallback;
	}
	return target;
}
