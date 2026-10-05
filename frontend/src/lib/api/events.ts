import { api, type ApiOptions } from './client';
import type { CursorPage, Event, EventVisibility, Post } from '$lib/types';

export interface CreateEventPayload {
	title: string;
	description?: string;
	location?: string;
	/** Area or venue shown on PUBLIC events until a viewer joins. */
	locationDisplay?: string;
	scheduledAt: string; // ISO instant
	gameId?: string;
	maxParticipants?: number;
	visibility: EventVisibility;
	/** Friends of the host only. */
	invitedUserIds?: string[];
}

/** PUT body: every field optional; an empty string clears description / location / locationDisplay. */
export type UpdateEventPayload = Partial<Omit<CreateEventPayload, 'invitedUserIds'>>;

export type EventListScope = 'upcoming' | 'past' | 'mine';

export const eventsApi = {
	/** Upcoming events in the caller's circle (hosting, invited, friends' events), soonest first. */
	getUpcoming: (opts?: ApiOptions): Promise<Event[]> => eventsApi.list('upcoming', 50, opts),

	list: (scope: EventListScope, limit = 50, opts?: ApiOptions): Promise<Event[]> =>
		api.get<Event[]>(`/api/v1/events?scope=${scope}&limit=${limit}`, opts),

	getMyEvents: (opts?: ApiOptions): Promise<Event[]> => api.get<Event[]>('/api/v1/events/me', opts),

	/** Events starting in [from, to) — at most 62 days. */
	getCalendar: (from: Date, to: Date, opts?: ApiOptions): Promise<Event[]> =>
		api.get<Event[]>(
			`/api/v1/events/calendar?from=${encodeURIComponent(from.toISOString())}&to=${encodeURIComponent(to.toISOString())}`,
			opts
		),

	/** Upcoming PUBLIC events from anyone, keyset-paginated. */
	getCommunity: (
		params: { gameId?: string; cursor?: string | null; limit?: number } = {},
		opts?: ApiOptions
	): Promise<CursorPage<Event>> => {
		const query = new URLSearchParams();
		if (params.gameId) query.set('gameId', params.gameId);
		if (params.cursor) query.set('cursor', params.cursor);
		query.set('limit', String(params.limit ?? 20));
		return api.get<CursorPage<Event>>(`/api/v1/events/community?${query.toString()}`, opts);
	},

	getEvent: (id: string, opts?: ApiOptions): Promise<Event> => api.get<Event>(`/api/v1/events/${id}`, opts),

	createEvent: (payload: CreateEventPayload): Promise<Event> => api.post<Event>('/api/v1/events', payload),

	updateEvent: (id: string, payload: UpdateEventPayload): Promise<Event> =>
		api.put<Event>(`/api/v1/events/${id}`, payload),

	cancelEvent: (id: string) => api.post<void>(`/api/v1/events/${id}/cancel`),

	/** Alias of cancelEvent, kept for existing callers. */
	deleteEvent: (id: string) => api.delete<void>(`/api/v1/events/${id}`),

	invite: (id: string, userIds: string[]): Promise<Event> =>
		api.post<Event>(`/api/v1/events/${id}/invites`, { userIds }),

	rsvp: (id: string, status: 'ACCEPTED' | 'DECLINED'): Promise<Event> =>
		api.post<Event>(`/api/v1/events/${id}/rsvp?status=${status}`),

	/** Leave an event you are going to (status becomes LEFT). */
	leaveEvent: (id: string) => api.delete<void>(`/api/v1/events/${id}/rsvp`),

	kick: (id: string, userId: string): Promise<Event> =>
		api.delete<Event>(`/api/v1/events/${id}/participants/${userId}`),

	/** Posts recorded for this event ("View Memories"), served by the posts API. */
	getMemories: (id: string, cursor?: string | null, opts?: ApiOptions): Promise<CursorPage<Post>> =>
		api.get<CursorPage<Post>>(
			`/api/v1/posts?eventId=${id}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`,
			opts
		)
};
