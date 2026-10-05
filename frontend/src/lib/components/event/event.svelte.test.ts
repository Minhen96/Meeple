import { render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiRequestError } from '$lib/api/client';
import { m } from '$lib/i18n';
import type { Event, EventParticipant } from '$lib/types';
import EventCard from './EventCard.svelte';
import MonthCalendar from './MonthCalendar.svelte';

const getCalendar = vi.hoisted(() => vi.fn());
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/events', () => ({ eventsApi: { getCalendar } }));

const participant = (id: string, status: EventParticipant['status'] = 'ACCEPTED'): EventParticipant => ({
	id,
	username: id,
	displayName: null,
	avatarUrl: null,
	status
});

function makeEvent(overrides: Partial<Event> = {}): Event {
	return {
		id: 'e1',
		host: { id: 'host', username: 'hosty', displayName: 'Host Person', avatarUrl: null },
		game: null,
		title: 'Catan night',
		description: null,
		location: '12 Main St',
		locationDisplay: null,
		scheduledAt: new Date(2026, 3, 18, 19, 0).toISOString(),
		maxParticipants: 4,
		participantCount: 2,
		visibility: 'FRIENDS',
		status: 'OPEN',
		myRsvp: null,
		isHost: false,
		reminderSent: false,
		participants: [participant('host'), participant('p1')],
		createdAt: '2026-01-01T00:00:00Z',
		...overrides
	};
}

describe('EventCard', () => {
	it('links to the event and shows title, host, players, place and status', () => {
		render(EventCard, { event: makeEvent() });
		const link = screen.getByRole('link');
		expect(link).toHaveAttribute('href', '/events/e1');
		expect(link).toHaveTextContent('Catan night');
		expect(link).toHaveTextContent('Host Person');
		expect(link).toHaveTextContent(m('event.card.players', { count: 2, max: 4 }));
		expect(link).toHaveTextContent('12 Main St');
		expect(link.className).not.toContain('opacity-70');
	});

	it('shows the game thumbnail instead of the date tile when there is one', () => {
		render(EventCard, {
			event: makeEvent({ game: { id: 'g', title: 'Catan', thumbnailUrl: 'https://img/catan.png' } as Event['game'] })
		});
		expect(screen.getByRole('img', { name: 'Catan' })).toHaveAttribute('src', 'https://img/catan.png');
	});

	it('renders muted for past events', () => {
		render(EventCard, { event: makeEvent({ status: 'COMPLETED' }), muted: true });
		expect(screen.getByRole('link').className).toContain('opacity-70');
	});

	it('shows "Going" for an accepted guest and stacks at most 4 avatars (+N)', () => {
		const participants = [participant('host'), ...['a', 'b', 'c', 'd', 'e', 'f'].map((id) => participant(id)), participant('x', 'INVITED')];
		render(EventCard, { event: makeEvent({ myRsvp: 'ACCEPTED', participants }) });
		expect(screen.getByText(m('event.card.going'))).toBeInTheDocument();
		expect(screen.getByText('+2')).toBeInTheDocument();
	});

	it('shows "Invited" for a pending invite and nothing for the host', () => {
		const { unmount } = render(EventCard, { event: makeEvent({ myRsvp: 'INVITED', participants: [] }) });
		expect(screen.getByText(m('event.card.invited'))).toBeInTheDocument();
		unmount();
		render(EventCard, { event: makeEvent({ myRsvp: 'ACCEPTED', isHost: true, participants: [participant('host')] }) });
		expect(screen.queryByText(m('event.card.going'))).toBeNull();
	});
});

describe('MonthCalendar', () => {
	const today = new Date();
	const todayAt = (h: number) => new Date(today.getFullYear(), today.getMonth(), today.getDate(), h).toISOString();
	const dayLabel = (d: Date) => d.toLocaleDateString('en', { weekday: 'long', month: 'long', day: 'numeric' });
	const monthTitle = (y: number, mo: number) => new Date(y, mo, 1).toLocaleDateString('en', { month: 'long', year: 'numeric' });

	beforeEach(() => {
		getCalendar.mockReset();
	});

	it('loads the visible grid range and marks days with events', async () => {
		getCalendar.mockResolvedValue([makeEvent({ id: 'a', scheduledAt: todayAt(10) }), makeEvent({ id: 'b', title: 'Azul', scheduledAt: todayAt(20) })]);
		render(MonthCalendar);
		expect(screen.getByRole('heading', { name: monthTitle(today.getFullYear(), today.getMonth()) })).toBeInTheDocument();
		const [from, to] = getCalendar.mock.calls[0] as [Date, Date];
		expect(from.getTime()).toBeLessThanOrEqual(new Date(today.getFullYear(), today.getMonth(), 1).getTime());
		expect(to.getTime()).toBeGreaterThan(new Date(today.getFullYear(), today.getMonth() + 1, 0).getTime());

		const day = await screen.findByRole('button', { name: m('event.calendar.hasEvents', { date: dayLabel(today), count: 2 }) });
		expect(day).toBeEnabled();
		// Days without events are not tappable.
		const empty = screen.getAllByRole('button').filter((b) => b.hasAttribute('disabled'));
		expect(empty.length).toBeGreaterThan(20);
	});

	it('tapping a day opens a sheet listing its events; closing hides it', async () => {
		getCalendar.mockResolvedValue([makeEvent({ id: 'a', scheduledAt: todayAt(10) }), makeEvent({ id: 'b', title: 'Azul', scheduledAt: todayAt(20) })]);
		render(MonthCalendar);
		await userEvent.click(await screen.findByRole('button', { name: m('event.calendar.hasEvents', { date: dayLabel(today), count: 2 }) }));
		const sheet = await screen.findByRole('dialog');
		expect(within(sheet).getAllByRole('link').map((a) => a.getAttribute('href'))).toEqual(['/events/a', '/events/b']);
		await userEvent.keyboard('{Escape}');
		await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
	});

	it('navigates months, reloading each range, and "Today" jumps back', async () => {
		getCalendar.mockResolvedValue([]);
		render(MonthCalendar);
		const next = new Date(today.getFullYear(), today.getMonth() + 1, 1);
		const prev = new Date(today.getFullYear(), today.getMonth() - 1, 1);

		expect(screen.queryByRole('button', { name: m('event.calendar.today') })).toBeNull();
		await userEvent.click(screen.getByRole('button', { name: m('event.calendar.next') }));
		expect(screen.getByRole('heading', { name: monthTitle(next.getFullYear(), next.getMonth()) })).toBeInTheDocument();
		await waitFor(() => expect(getCalendar).toHaveBeenCalledTimes(2));

		await userEvent.click(screen.getByRole('button', { name: m('event.calendar.today') }));
		await userEvent.click(screen.getByRole('button', { name: m('event.calendar.prev') }));
		expect(screen.getByRole('heading', { name: monthTitle(prev.getFullYear(), prev.getMonth()) })).toBeInTheDocument();
		await waitFor(() => expect(getCalendar).toHaveBeenCalledTimes(4));
	});

	it('shows an error alert when the range fails to load', async () => {
		getCalendar.mockRejectedValue(new ApiRequestError('INTERNAL', 'boom', 500));
		render(MonthCalendar);
		expect(await screen.findByRole('alert')).toBeInTheDocument();
	});

	it('ignores a stale response that arrives after navigating', async () => {
		let resolveFirst: (v: Event[]) => void = () => {};
		getCalendar
			.mockImplementationOnce(() => new Promise<Event[]>((r) => (resolveFirst = r)))
			.mockResolvedValue([]);
		render(MonthCalendar);
		await userEvent.click(screen.getByRole('button', { name: m('event.calendar.next') }));
		resolveFirst([makeEvent({ id: 'stale', scheduledAt: todayAt(10) })]);
		await waitFor(() => expect(getCalendar).toHaveBeenCalledTimes(2));
		await userEvent.click(screen.getByRole('button', { name: m('event.calendar.prev') }));
		await waitFor(() => expect(getCalendar).toHaveBeenCalledTimes(3));
		expect(screen.queryByRole('button', { name: m('event.calendar.hasEvents', { date: dayLabel(today), count: 1 }) })).toBeNull();
	});
});
