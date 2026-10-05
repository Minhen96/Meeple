import { postsApi } from '$lib/api/posts';
import { eventsApi } from '$lib/api/events';
import { matchesApi } from '$lib/api/matches';
import { friendsApi } from '$lib/api/friends';
import type { CursorPage, FeedItem } from '$lib/types';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch }) => {
	const { user } = await parent();

	// The feed failing must not break the page: the client shows the error state and retries.
	const [feed, myEvents, matchSuggestions, friends, sent] = await Promise.all([
		postsApi.getFeedPage(null, 20, { fetch }).catch((): CursorPage<FeedItem> | null => null),
		eventsApi.getMyEvents({ fetch }).catch(() => []),
		matchesApi.getSuggestions({ fetch }).catch(() => []),
		friendsApi.getFriends(0, 1, { fetch }).catch(() => null),
		friendsApi.getSent(0, 1, { fetch }).catch(() => null)
	]);

	const now = Date.now();
	const upcomingEvents = myEvents
		.filter((e) => new Date(e.scheduledAt).getTime() >= now && e.status !== 'CANCELLED')
		.sort((a, b) => new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime());

	return {
		user,
		feed,
		upcomingEvents,
		matchSuggestions,
		friendCount: friends?.meta.total ?? 0,
		pendingSentCount: sent?.meta.total ?? 0
	};
};
