import { describe, expect, it } from 'vitest';
import { eventsViewHref, parseEventsView } from './eventsView';
import { filterFriends } from './friendFilter';

describe('events URL state', () => {
	it('parses known values and defaults the rest', () => {
		expect(parseEventsView(new URLSearchParams('tab=past&view=calendar'))).toEqual({ tab: 'past', view: 'calendar' });
		expect(parseEventsView(new URLSearchParams('tab=nope&view=grid'))).toEqual({ tab: 'upcoming', view: 'list' });
		expect(parseEventsView(new URLSearchParams())).toEqual({ tab: 'upcoming', view: 'list' });
	});

	it('builds canonical links without default parameters', () => {
		expect(eventsViewHref('upcoming', 'list')).toBe('/events');
		expect(eventsViewHref('community', 'list')).toBe('/events?tab=community');
		expect(eventsViewHref('upcoming', 'calendar')).toBe('/events?view=calendar');
		expect(eventsViewHref('past', 'calendar')).toBe('/events?tab=past&view=calendar');
	});
});

describe('filterFriends', () => {
	const friends = [
		{ username: 'ana_b', displayName: 'Ana Bélanger' },
		{ username: 'chen', displayName: null },
		{ username: 'zoe', displayName: 'Zoë' }
	];

	it('matches username or display name, ignoring case and accents', () => {
		expect(filterFriends(friends, 'BELANGER').map((f) => f.username)).toEqual(['ana_b']);
		expect(filterFriends(friends, 'zoe').map((f) => f.username)).toEqual(['zoe']);
		expect(filterFriends(friends, 'che').map((f) => f.username)).toEqual(['chen']);
		expect(filterFriends(friends, '  ')).toHaveLength(3);
		expect(filterFriends(friends, 'xyz')).toEqual([]);
	});
});
