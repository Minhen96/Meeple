// URL state of the events screen: `?tab=upcoming|past|community&view=list|calendar`.

export type EventsTab = 'upcoming' | 'past' | 'community';
export type EventsView = 'list' | 'calendar';

const TABS: readonly EventsTab[] = ['upcoming', 'past', 'community'];
const VIEWS: readonly EventsView[] = ['list', 'calendar'];

export function parseEventsView(params: URLSearchParams): { tab: EventsTab; view: EventsView } {
	const tab = params.get('tab');
	const view = params.get('view');
	return {
		tab: TABS.includes(tab as EventsTab) ? (tab as EventsTab) : 'upcoming',
		view: VIEWS.includes(view as EventsView) ? (view as EventsView) : 'list'
	};
}

/** Query string for a tab/view, leaving defaults out so `/events` stays the canonical URL. */
export function eventsViewHref(tab: EventsTab, view: EventsView): string {
	const params = new URLSearchParams();
	if (tab !== 'upcoming') params.set('tab', tab);
	if (view !== 'list') params.set('view', view);
	const query = params.toString();
	return query ? `/events?${query}` : '/events';
}
