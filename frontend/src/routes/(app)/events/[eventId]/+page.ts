import { eventsApi } from '$lib/api/events';
import { throwLoadError } from '$lib/api/load';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user } = await parent();
	try {
		const event = await eventsApi.getEvent(params.eventId, { fetch });
		return { user, event };
	} catch (err) {
		throwLoadError(err, url, 'Event not found');
	}
};
