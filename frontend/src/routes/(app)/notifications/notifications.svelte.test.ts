// Notifications screen: grouping (Today / This Week / Earlier), read/delete actions,
// open-and-navigate, mark-all-read, empty / error states and infinite scroll.
import { act, render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { get } from 'svelte/store';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { goto } from '$app/navigation';
import { m } from '$lib/i18n';
import { notifications, resetNotifications, unreadCount } from '$lib/stores/notifications';
import type { Notification } from '$lib/types';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({
	toast: { success: vi.fn(), error: vi.fn() },
	api: {
		list: vi.fn(),
		getUnreadCount: vi.fn(),
		markRead: vi.fn(),
		markAllRead: vi.fn(),
		remove: vi.fn()
	}
}));
vi.mock('svelte-sonner', () => ({ toast: h.toast }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/notifications', () => ({ notificationsApi: h.api }));

const HOUR = 3600_000;
const DAY = 24 * HOUR;

function notif(id: string, ageMs: number, overrides: Partial<Notification> = {}): Notification {
	return {
		id,
		type: 'POST_LIKE',
		title: `TITLE_${id}`,
		body: null,
		actor: { id: 'a', username: 'ann', displayName: 'Ann', avatarUrl: null, deleted: false },
		data: { path: `/posts/${id}` },
		read: false,
		createdAt: new Date(Date.now() - ageMs).toISOString(),
		...overrides
	} as Notification;
}

const page = (items: Notification[], nextCursor: string | null = null) => ({ items, nextCursor, hasMore: nextCursor !== null });

let observerCallback: IntersectionObserverCallback | null;

beforeEach(() => {
	resetNotifications();
	for (const fn of [...Object.values(h.api), ...Object.values(h.toast)]) fn.mockReset();
	vi.mocked(goto).mockClear();
	h.api.markRead.mockResolvedValue(undefined);
	h.api.markAllRead.mockResolvedValue(undefined);
	h.api.remove.mockResolvedValue(undefined);
	observerCallback = null;
	vi.stubGlobal(
		'IntersectionObserver',
		class {
			constructor(cb: IntersectionObserverCallback) {
				observerCallback = cb;
			}
			observe() {}
			disconnect() {}
		}
	);
});

afterEach(() => {
	vi.unstubAllGlobals();
});

const intersect = () =>
	act(() => observerCallback?.([{ isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver));

describe('notifications page', () => {
	it('groups newest-first items into Today / This Week / Earlier', async () => {
		const now = new Date();
		const minutesSinceMidnight = now.getHours() * 60 + now.getMinutes();
		const todayAge = Math.min(5 * 60_000, minutesSinceMidnight * 60_000 / 2);
		h.api.list.mockResolvedValue(page([notif('t', todayAge), notif('w', 2 * DAY + HOUR), notif('e', 30 * DAY)]));
		h.api.getUnreadCount.mockResolvedValue(3);
		render(Page);

		const sections = await screen.findAllByRole('heading', { level: 3 });
		expect(sections.map((s) => s.textContent?.trim())).toEqual([
			m('notif.group.today'),
			m('notif.group.thisWeek'),
			m('notif.group.earlier')
		]);
		const lists = screen.getAllByRole('list');
		expect(within(lists[0]).getByText('TITLE_t')).toBeInTheDocument();
		expect(within(lists[1]).getByText('TITLE_w')).toBeInTheDocument();
		expect(within(lists[2]).getByText('TITLE_e')).toBeInTheDocument();
		expect(h.api.list).toHaveBeenCalledWith(null, 30);
		expect(get(unreadCount)).toBe(3);
	});

	it('shows the empty state', async () => {
		h.api.list.mockResolvedValue(page([]));
		h.api.getUnreadCount.mockResolvedValue(0);
		render(Page);
		expect(await screen.findByText(m('notif.empty.title'))).toBeInTheDocument();
		expect(screen.queryByRole('button', { name: m('notif.page.markAllRead') })).toBeNull();
	});

	it('shows a retryable error state', async () => {
		h.api.list.mockRejectedValueOnce(new Error('net')).mockResolvedValueOnce(page([notif('n1', HOUR)]));
		h.api.getUnreadCount.mockResolvedValue(1);
		render(Page);
		await userEvent.click(await screen.findByRole('button', { name: m('notif.list.retry') }));
		expect(await screen.findByText('TITLE_n1')).toBeInTheDocument();
	});

	it('opening an unread item marks it read and navigates to its in-app path', async () => {
		h.api.list.mockResolvedValue(page([notif('n1', HOUR)]));
		h.api.getUnreadCount.mockResolvedValue(1);
		render(Page);
		await userEvent.click(await screen.findByRole('button', { name: /TITLE_n1/ }));
		expect(goto).toHaveBeenCalledWith('/posts/n1');
		expect(h.api.markRead).toHaveBeenCalledWith('n1');
		await waitFor(() => expect(get(notifications)[0].read).toBe(true));
		expect(get(unreadCount)).toBe(0);
	});

	it('opening a read item or one with an unsafe path does not re-mark it and stays in-app', async () => {
		h.api.list.mockResolvedValue(page([notif('n1', HOUR, { read: true, data: { path: '//evil.test' } } as Partial<Notification>)]));
		h.api.getUnreadCount.mockResolvedValue(0);
		render(Page);
		await userEvent.click(await screen.findByRole('button', { name: /TITLE_n1/ }));
		expect(goto).toHaveBeenCalledWith('/notifications');
		expect(h.api.markRead).not.toHaveBeenCalled();
		expect(screen.queryByRole('button', { name: m('notif.item.markRead') })).toBeNull();
	});

	it('mark read and delete per item; failures toast', async () => {
		h.api.list.mockResolvedValue(page([notif('n1', HOUR), notif('n2', HOUR)]));
		h.api.getUnreadCount.mockResolvedValue(2);
		render(Page);
		await screen.findByText('TITLE_n1');

		await userEvent.click(screen.getAllByRole('button', { name: m('notif.item.markRead') })[0]);
		expect(h.api.markRead).toHaveBeenCalledWith('n1');
		await waitFor(() => expect(get(unreadCount)).toBe(1));

		await userEvent.click(screen.getAllByRole('button', { name: m('notif.item.delete') })[1]);
		expect(h.api.remove).toHaveBeenCalledWith('n2');
		await waitFor(() => expect(screen.queryByText('TITLE_n2')).toBeNull());
		expect(get(unreadCount)).toBe(0);

		h.api.remove.mockRejectedValueOnce(new Error('x'));
		await userEvent.click(screen.getByRole('button', { name: m('notif.item.delete') }));
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('notif.action.failed')));
		expect(screen.getByText('TITLE_n1')).toBeInTheDocument();
	});

	it('mark read failure toasts', async () => {
		h.api.list.mockResolvedValue(page([notif('n1', HOUR)]));
		h.api.getUnreadCount.mockResolvedValue(1);
		h.api.markRead.mockRejectedValue(new Error('x'));
		render(Page);
		await userEvent.click(await screen.findByRole('button', { name: m('notif.item.markRead') }));
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('notif.action.failed')));
	});

	it('mark all read clears the badge; failure toasts', async () => {
		h.api.list.mockResolvedValue(page([notif('n1', HOUR), notif('n2', HOUR)]));
		h.api.getUnreadCount.mockResolvedValue(2);
		render(Page);
		h.api.markAllRead.mockRejectedValueOnce(new Error('x'));
		await userEvent.click(await screen.findByRole('button', { name: m('notif.page.markAllRead') }));
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('notif.action.failed')));

		await userEvent.click(screen.getByRole('button', { name: m('notif.page.markAllRead') }));
		await waitFor(() => expect(screen.queryByRole('button', { name: m('notif.page.markAllRead') })).toBeNull());
		expect(get(notifications).every((n) => n.read)).toBe(true);
	});

	it('loads the next page when the sentinel scrolls into view, skipping duplicates', async () => {
		h.api.list.mockResolvedValueOnce(page([notif('n1', HOUR)], 'c2'));
		h.api.getUnreadCount.mockResolvedValue(1);
		render(Page);
		await screen.findByText('TITLE_n1');
		await waitFor(() => expect(observerCallback).not.toBeNull());

		h.api.list.mockResolvedValueOnce(page([notif('n1', HOUR), notif('n3', 40 * DAY)]));
		await intersect();
		expect(await screen.findByText('TITLE_n3')).toBeInTheDocument();
		expect(h.api.list).toHaveBeenLastCalledWith('c2', 30);
		expect(screen.getAllByText('TITLE_n1')).toHaveLength(1);

		// No more pages: further intersections do nothing.
		await intersect();
		expect(h.api.list).toHaveBeenCalledTimes(2);
	});

	it('a failed next page toasts and can be retried', async () => {
		h.api.list.mockResolvedValueOnce(page([notif('n1', HOUR)], 'c2'));
		h.api.getUnreadCount.mockResolvedValue(1);
		render(Page);
		await screen.findByText('TITLE_n1');
		h.api.list.mockRejectedValueOnce(new Error('x'));
		await intersect();
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('notif.list.loadFailed')));
	});
});
