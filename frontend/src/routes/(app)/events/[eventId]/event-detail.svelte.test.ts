// Event detail: switching to another event resets per-event UI state and ignores responses for
// the previous one; live topic frames (old payload with participants, new {eventId,
// participantCount, status}) trigger a debounced REST re-fetch.
import { act, render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { m } from '$lib/i18n';
import type { Event, EventParticipant, Post } from '$lib/types';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({
	events: { getEvent: vi.fn(), getMemories: vi.fn() },
	topics: new Map<string, (frame: { body: string }) => void>(),
	unsubscribed: [] as string[]
}));
vi.mock('svelte-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/events', () => ({ eventsApi: h.events }));
vi.mock('$lib/stores/websocket', () => ({
	subscribeTopic: (topic: string, cb: (frame: { body: string }) => void) => {
		h.topics.set(topic, cb);
		return () => {
			h.topics.delete(topic);
			h.unsubscribed.push(topic);
		};
	}
}));

const participant = (id: string): EventParticipant => ({
	id,
	username: id,
	displayName: null,
	avatarUrl: null,
	status: 'ACCEPTED'
});

function makeEvent(id: string, overrides: Partial<Event> = {}): Event {
	return {
		id,
		host: { id: 'host', username: 'hosty', displayName: 'Host Person', avatarUrl: null },
		game: null,
		title: `TITLE_${id}`,
		description: null,
		location: '12 Main St',
		locationDisplay: null,
		scheduledAt: new Date(2026, 3, 18, 19, 0).toISOString(),
		maxParticipants: 4,
		participantCount: 2,
		visibility: 'FRIENDS',
		status: 'COMPLETED',
		myRsvp: 'ACCEPTED',
		isHost: false,
		reminderSent: false,
		participants: [participant('host'), participant('p1')],
		createdAt: '2026-01-01T00:00:00Z',
		...overrides
	};
}

const memory: Post = {
	id: 'm1',
	author: { id: 'p1', username: 'p1', displayName: null, avatarUrl: null, deleted: false },
	caption: 'MEMORY_CAPTION',
	location: null,
	playedAt: null,
	imageUrls: [],
	game: null,
	eventId: 'a',
	taggedUsers: [],
	likeCount: 0,
	commentCount: 0,
	likedByMe: false,
	isBookmarked: false,
	createdAt: '2026-04-18T20:00:00Z',
	editedAt: null
};
const pageData = (event: Event) => ({ data: { user: null, event } as never });
const title = (id: string) => screen.queryByRole('heading', { level: 1, name: `TITLE_${id}` });

beforeEach(() => {
	h.events.getEvent.mockReset();
	h.events.getMemories.mockReset();
	h.topics.clear();
	h.unsubscribed.length = 0;
});

afterEach(() => {
	vi.useRealTimers();
});

describe('event detail across events', () => {
	it('clears the previous event memories and follows the new topic', async () => {
		h.events.getMemories.mockRejectedValue(new Error('500'));
		const { rerender } = render(Page, pageData(makeEvent('a')));
		await userEvent.click(screen.getByRole('button', { name: m('event.detail.viewMemories') }));
		await waitFor(() => expect(screen.getByText(m('event.detail.memoriesError'))).toBeInTheDocument());

		await rerender(pageData(makeEvent('b')));
		expect(title('b')).toBeInTheDocument();
		expect(screen.queryByText(m('event.detail.memoriesError'))).toBeNull();
		expect(screen.queryByText(m('event.detail.memoriesTitle'))).toBeNull();
		expect(h.unsubscribed).toEqual(['/topic/events/a']);
		expect([...h.topics.keys()]).toEqual(['/topic/events/b']);
	});

	it('closes an open confirmation when the event changes', async () => {
		const going = { status: 'OPEN' as const, myRsvp: 'ACCEPTED' as const };
		const { rerender } = render(Page, pageData(makeEvent('a', going)));
		await userEvent.click(screen.getByRole('button', { name: m('event.action.leave') }));
		expect(screen.getByText(m('event.manage.leaveTitle'))).toBeInTheDocument();
		await rerender(pageData(makeEvent('b', going)));
		await waitFor(() => expect(screen.queryByText(m('event.manage.leaveTitle'))).toBeNull());
	});

	it('drops memories that arrive for the previous event', async () => {
		let resolveMemories: (page: { items: Post[] }) => void = () => {};
		h.events.getMemories.mockReturnValue(new Promise((r) => (resolveMemories = r)));
		const { rerender } = render(Page, pageData(makeEvent('a')));
		await userEvent.click(screen.getByRole('button', { name: m('event.detail.viewMemories') }));
		await rerender(pageData(makeEvent('b')));
		await act(() => resolveMemories({ items: [memory] }));
		expect(screen.queryByText('MEMORY_CAPTION')).toBeNull();
		expect(screen.queryByText(m('event.detail.memoriesTitle'))).toBeNull();
	});
});

describe('live updates', () => {
	it.each([
		['new payload', { eventId: 'a', participantCount: 3, status: 'FULL' }],
		['legacy payload with participants', { eventId: 'a', participantCount: 3, status: 'FULL', participants: [] }]
	])('a %s triggers one debounced REST re-fetch', async (_label, payload) => {
		vi.useFakeTimers();
		h.events.getEvent.mockResolvedValue(makeEvent('a', { title: 'TITLE_a', status: 'OPEN', participantCount: 3 }));
		render(Page, pageData(makeEvent('a', { status: 'OPEN' })));
		const send = h.topics.get('/topic/events/a');
		expect(send).toBeDefined();
		send?.({ body: JSON.stringify(payload) });
		send?.({ body: JSON.stringify(payload) });
		await vi.advanceTimersByTimeAsync(299);
		expect(h.events.getEvent).not.toHaveBeenCalled();
		await vi.advanceTimersByTimeAsync(1);
		expect(h.events.getEvent).toHaveBeenCalledTimes(1);
		expect(h.events.getEvent).toHaveBeenCalledWith('a');
	});

	it('applies the re-fetched event', async () => {
		vi.useFakeTimers();
		h.events.getEvent.mockResolvedValue(makeEvent('a', { title: 'TITLE_a2', status: 'OPEN' }));
		render(Page, pageData(makeEvent('a', { status: 'OPEN' })));
		h.topics.get('/topic/events/a')?.({ body: '{"eventId":"a","participantCount":3,"status":"OPEN"}' });
		await vi.advanceTimersByTimeAsync(300);
		vi.useRealTimers();
		await waitFor(() => expect(title('a2')).toBeInTheDocument());
	});

	it('ignores frames naming another event', async () => {
		vi.useFakeTimers();
		render(Page, pageData(makeEvent('a', { status: 'OPEN' })));
		h.topics.get('/topic/events/a')?.({ body: '{"eventId":"zzz","participantCount":1,"status":"OPEN"}' });
		await vi.advanceTimersByTimeAsync(500);
		expect(h.events.getEvent).not.toHaveBeenCalled();
	});

	it('drops a refresh for the previous event that resolves after switching', async () => {
		vi.useFakeTimers();
		let resolveOld: (e: Event) => void = () => {};
		h.events.getEvent.mockReturnValueOnce(new Promise((r) => (resolveOld = r)));
		const { rerender } = render(Page, pageData(makeEvent('a', { status: 'OPEN' })));
		h.topics.get('/topic/events/a')?.({ body: '{"eventId":"a","participantCount":3,"status":"OPEN"}' });
		await vi.advanceTimersByTimeAsync(300);
		expect(h.events.getEvent).toHaveBeenCalledWith('a');
		vi.useRealTimers();

		await rerender(pageData(makeEvent('b', { status: 'OPEN' })));
		await act(() => resolveOld(makeEvent('a', { title: 'TITLE_stale', status: 'OPEN' })));
		expect(title('stale')).toBeNull();
		expect(title('b')).toBeInTheDocument();
	});
});
