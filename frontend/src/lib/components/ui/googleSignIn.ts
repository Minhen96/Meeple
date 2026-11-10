/**
 * Whether Google sign-in is available in this build: the GSI button only renders with a client
 * id, so screens hide the "or" divider and the button slot without one.
 */
export function googleSignInConfigured(
	clientId: unknown = import.meta.env.VITE_GOOGLE_CLIENT_ID
): boolean {
	return typeof clientId === 'string' && clientId.trim() !== '';
}
