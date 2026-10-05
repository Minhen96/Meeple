import { eventsApi } from '$lib/api/events';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch }) => {
	const { user } = await parent();

	const [upcoming, mine] = await Promise.all([
		eventsApi.getUpcoming({ fetch }).catch(() => []),
		eventsApi.getMyEvents({ fetch }).catch(() => [])
	]);

	return { user, upcoming, mine };
};
