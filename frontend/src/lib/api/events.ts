import { api } from './client';
import type { ApiResponse, Event } from '$lib/types';

export interface CreateEventPayload {
	title: string;
	description?: string;
	location?: string;
	scheduledAt: string; // ISO instant
	gameId?: string;
	maxParticipants?: number;
	visibility: 'PUBLIC' | 'FRIENDS' | 'INVITE_ONLY';
}

export const eventsApi = {
	getUpcoming: async (): Promise<Event[]> => {
		const res = await api.get<Event[]>('/api/v1/events');
		return res;
	},

	getMyEvents: async (): Promise<Event[]> => {
		const res = await api.get<Event[]>('/api/v1/events/mine');
		return res;
	},

	getEvent: async (id: string): Promise<Event> => {
		const res = await api.get<Event>(`/api/v1/events/${id}`);
		return res;
	},

	createEvent: async (payload: CreateEventPayload): Promise<Event> => {
		const res = await api.post<Event>('/api/v1/events', payload);
		return res;
	},

	updateEvent: async (id: string, payload: Partial<CreateEventPayload>): Promise<Event> => {
		const res = await api.put<Event>(`/api/v1/events/${id}`, payload);
		return res;
	},

	deleteEvent: (id: string) => api.delete<void>(`/api/v1/events/${id}`),

	rsvp: async (id: string, status: 'ACCEPTED' | 'DECLINED' | 'INVITED'): Promise<Event> => {
		const res = await api.post<Event>(`/api/v1/events/${id}/rsvp?status=${status}`);
		return res;
	},

	leaveEvent: (id: string) => api.delete<void>(`/api/v1/events/${id}/rsvp`)
};
