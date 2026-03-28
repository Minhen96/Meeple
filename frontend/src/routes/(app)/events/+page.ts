import { eventsApi } from '$lib/api/events';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	const { user } = await parent();

	const [upcoming, mine] = await Promise.all([
		eventsApi.getUpcoming().catch(() => []),
		eventsApi.getMyEvents().catch(() => [])
	]);

	return { user, upcoming, mine };
};
