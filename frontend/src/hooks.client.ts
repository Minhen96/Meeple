import type { ClientInit, HandleClientError } from '@sveltejs/kit';
import { captureError, initObservability } from '$lib/observability';

// Not awaited: never delay hydration on loading the (optional) Sentry/PostHog SDKs.
export const init: ClientInit = () => {
	void initObservability();
};

export const handleError: HandleClientError = ({ error, status }) => {
	// 404s and other expected HTTP errors are not bugs.
	if (status < 500) return;
	captureError(error);
};
