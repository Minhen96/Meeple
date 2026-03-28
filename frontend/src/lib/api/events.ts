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
		const res = await api.get<ApiResponse<Event[]>>('/api/v1/events');
		return res.data;
	},

	getMyEvents: async (): Promise<Event[]> => {
		const res = await api.get<ApiResponse<Event[]>>('/api/v1/events/me');
		return res.data;
	},

	getEvent: async (id: string): Promise<Event> => {
		const res = await api.get<ApiResponse<Event>>(`/api/v1/events/${id}`);
		return res.data;
	},

	createEvent: async (payload: CreateEventPayload): Promise<Event> => {
		const res = await api.post<ApiResponse<Event>>('/api/v1/events', payload);
		return res.data;
	},

	updateEvent: async (id: string, payload: Partial<CreateEventPayload>): Promise<Event> => {
		const res = await api.put<ApiResponse<Event>>(`/api/v1/events/${id}`, payload);
		return res.data;
	},

	deleteEvent: (id: string) => api.delete<void>(`/api/v1/events/${id}`),

	rsvp: async (id: string, status: 'ACCEPTED' | 'DECLINED' | 'INVITED'): Promise<Event> => {
		const res = await api.post<ApiResponse<Event>>(`/api/v1/events/${id}/rsvp?status=${status}`);
		return res.data;
	},

	leaveEvent: (id: string) => api.delete<void>(`/api/v1/events/${id}/rsvp`)
};
