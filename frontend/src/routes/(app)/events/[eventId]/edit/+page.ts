import { eventsApi } from '$lib/api/events';
import { throwLoadError } from '$lib/api/load';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	// Wait for the root layout (which may refresh the session) before fetching.
	await parent();
	try {
		const event = await eventsApi.getEvent(params.eventId, { fetch });
		return { event };
	} catch (err) {
		throwLoadError(err, url, 'Event not found');
	}
};
