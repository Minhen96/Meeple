import { eventsApi } from '$lib/api/events';
import { parseEventsView } from '$lib/components/event/eventsView';
import type { Event } from '$lib/types';
import type { PageLoad } from './$types';

/**
 * `/events?tab=upcoming|past|community&view=list|calendar`. Only the list for the active tab is
 * loaded here; the calendar loads its own month range.
 */
export const load: PageLoad = async ({ parent, fetch, url }) => {
	const { user } = await parent();
	const { tab, view } = parseEventsView(url.searchParams);

	let events: Event[] = [];
	let nextCursor: string | null = null;
	let loadFailed = false;
	if (view === 'list') {
		try {
			if (tab === 'community') {
				const page = await eventsApi.getCommunity({}, { fetch });
				events = page.items;
				nextCursor = page.hasMore ? page.nextCursor : null;
			} else {
				events = await eventsApi.list(tab, 50, { fetch });
			}
		} catch {
			loadFailed = true;
		}
	}
	return { user, tab, view, events, nextCursor, loadFailed };
};
