import { postsApi } from '$lib/api/posts';
import { eventsApi } from '$lib/api/events';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	const { user } = await parent();

	const [posts, upcomingEvents] = await Promise.all([
		postsApi.getFeed(0, 20).catch(() => []),
		eventsApi.getUpcoming().catch(() => [])
	]);

	return { user, posts, upcomingEvents };
};
