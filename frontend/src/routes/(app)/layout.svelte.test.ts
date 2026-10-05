// App shell: the layout only seeds the unread badge; it never writes the notifications list
// (a cold load onto /notifications must keep the screen's first page).
import { render, waitFor } from '@testing-library/svelte';
import { get } from 'svelte/store';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { page } from '$app/state';
import { notifications, resetNotifications, unreadCount } from '$lib/stores/notifications';
import type { Notification } from '$lib/types';
import Layout from './+layout.svelte';

const h = vi.hoisted(() => ({
	api: { getAll: vi.fn(), getUnreadCount: vi.fn(), list: vi.fn() }
}));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/notifications', () => ({ notificationsApi: h.api }));

const item = { id: 'n1', type: 'POST_LIKE', read: false, createdAt: new Date().toISOString() } as Notification;

beforeEach(() => {
	resetNotifications();
	for (const fn of Object.values(h.api)) fn.mockReset();
	page.url = new URL('http://localhost/notifications');
});

afterEach(() => {
	page.url = new URL('http://localhost/');
});

describe('(app) layout', () => {
	it('fetches only the unread count and leaves the list loaded by the screen alone', async () => {
		let resolveCount: (n: number) => void = () => {};
		h.api.getUnreadCount.mockReturnValue(new Promise<number>((r) => (resolveCount = r)));
		h.api.getAll.mockResolvedValue({ data: [] });
		render(Layout);
		// the notifications screen loads its first page while the layout request is in flight
		notifications.set([item]);
		resolveCount(7);
		await waitFor(() => expect(get(unreadCount)).toBe(7));
		expect(get(notifications)).toEqual([item]);
		expect(h.api.getAll).not.toHaveBeenCalled();
		expect(h.api.list).not.toHaveBeenCalled();
	});

	it('tolerates a failed count request', async () => {
		h.api.getUnreadCount.mockRejectedValue(new Error('net'));
		render(Layout);
		await waitFor(() => expect(h.api.getUnreadCount).toHaveBeenCalled());
		expect(get(unreadCount)).toBeNull();
	});
});
