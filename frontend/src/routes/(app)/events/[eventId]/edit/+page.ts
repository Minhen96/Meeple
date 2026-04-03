import { eventsApi } from '$lib/api/events';
import type { PageLoad } from './$types';
import { error } from '@sveltejs/kit';

export const load: PageLoad = async ({ params }) => {
	try {
		const event = await eventsApi.getEvent(params.eventId);
		return { event };
	} catch (err) {
		console.error('Error loading event for edit:', err);
		throw error(404, 'Event not found');
	}
};
