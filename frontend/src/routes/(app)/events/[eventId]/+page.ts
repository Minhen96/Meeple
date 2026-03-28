import { eventsApi } from '$lib/api/events';
import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent }) => {
	const { user } = await parent();
	try {
		const event = await eventsApi.getEvent(params.eventId);
		return { user, event };
	} catch {
		throw error(404, 'Event not found');
	}
};
