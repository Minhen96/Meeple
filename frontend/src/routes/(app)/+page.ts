import { postsApi } from '$lib/api/posts';
import { eventsApi } from '$lib/api/events';
import { matchesApi } from '$lib/api/matches';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch }) => {
	const { user } = await parent();

	const [posts, upcomingEvents, matchSuggestions] = await Promise.all([
		postsApi.getFeed(0, 20, { fetch }).catch(() => []),
		eventsApi.getUpcoming({ fetch }).catch(() => []),
		matchesApi.getSuggestions({ fetch }).catch(() => [])
	]);

	return { user, posts, upcomingEvents, matchSuggestions };
};
