import { postsApi } from '$lib/api/posts';
import { eventsApi } from '$lib/api/events';
import { matchesApi } from '$lib/api/matches';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	const { user } = await parent();

	const [posts, upcomingEvents, matchSuggestions] = await Promise.all([
		postsApi.getFeed(0, 20).catch(() => []),
		eventsApi.getUpcoming().catch(() => []),
		matchesApi.getSuggestions().catch(() => [])
	]);

	return { user, posts, upcomingEvents, matchSuggestions };
};
