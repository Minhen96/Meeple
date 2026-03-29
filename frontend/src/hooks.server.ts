import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
	const response = await resolve(event);
	
	// Required for Google Identity Services callback to work
	// It allows the Google popup to communicate back to your window
	response.headers.set('Cross-Origin-Opener-Policy', 'same-origin-allow-popups');
	
	return response;
};
