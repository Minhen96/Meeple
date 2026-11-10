// Desktop layout pieces of the social screens: the home rail's friend widgets, the saved-posts
// grid, and the report / tag pickers rendered through the shared BottomSheet.
import { render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { m } from '$lib/i18n';
import type { FriendRequest, Post, SuggestedUser, User } from '$lib/types';
import FriendsRail from './FriendsRail.svelte';
import PostList from './PostList.svelte';
import ReportSheet from './ReportSheet.svelte';
import PostTagsEditor from './PostTagsEditor.svelte';

const h = vi.hoisted(() => ({
	toast: { success: vi.fn(), error: vi.fn() },
	friends: {
		getReceived: vi.fn(),
		suggestFriends: vi.fn(),
		accept: vi.fn(),
		decline: vi.fn(),
		sendRequest: vi.fn(),
		cancelTo: vi.fn(),
		getFriends: vi.fn()
	},
	reports: { report: vi.fn() }
}));
vi.mock('svelte-sonner', () => ({ toast: h.toast }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/friends', () => ({ friendsApi: h.friends, reportsApi: h.reports }));
vi.mock('$lib/api/games', () => ({ gamesApi: { search: vi.fn().mockResolvedValue([]) } }));

function user(id: string, name: string): User {
	return { id, username: id, displayName: name, avatarUrl: null } as User;
}

function request(id: string, sender: User): FriendRequest {
	return { id, sender, receiver: user('me', 'Me'), status: 'PENDING', createdAt: '' } as FriendRequest;
}

const page = <T,>(data: T[], total = data.length) => ({
	data,
	meta: { page: 0, size: 4, total, hasMore: total > data.length }
});

beforeEach(() => {
	for (const group of [h.toast, h.friends, h.reports]) for (const fn of Object.values(group)) fn.mockReset();
});

describe('FriendsRail', () => {
	const suggestion: SuggestedUser = {
		id: 'sam',
		username: 'sam',
		displayName: 'Sam',
		avatarUrl: null,
		sharedGames: 3
	};

	it('lists requests to answer and people you may know', async () => {
		h.friends.getReceived.mockResolvedValue(page([request('r1', user('erin', 'Erin'))], 5));
		h.friends.suggestFriends.mockResolvedValue([suggestion]);
		render(FriendsRail);

		const requests = await screen.findByTestId('rail-requests');
		expect(within(requests).getByText('Erin')).toBeInTheDocument();
		expect(within(requests).getByText(`${m('social.home.requestsTitle')} (5)`)).toBeInTheDocument();
		const people = screen.getByTestId('rail-suggestions');
		expect(within(people).getByText('Sam')).toBeInTheDocument();
		expect(within(people).getByText(m('social.people.sharedGames', { count: 3 }))).toBeInTheDocument();
		expect(within(people).getByRole('link', { name: m('social.home.seeAll') })).toHaveAttribute(
			'href',
			'/people'
		);
		expect(h.friends.getReceived).toHaveBeenCalledWith(0, 4);
		expect(h.friends.suggestFriends).toHaveBeenCalledWith(4);
	});

	it('accepts or declines a request in place', async () => {
		h.friends.getReceived.mockResolvedValue(
			page([request('r1', user('erin', 'Erin')), request('r2', user('finn', 'Finn'))])
		);
		h.friends.suggestFriends.mockResolvedValue([]);
		h.friends.accept.mockResolvedValue({});
		h.friends.decline.mockResolvedValue({});
		render(FriendsRail);

		await userEvent.click(
			await screen.findByRole('button', { name: `${m('social.friend.accept')} · Erin` })
		);
		expect(h.friends.accept).toHaveBeenCalledWith('r1');
		await waitFor(() => expect(screen.queryByText('Erin')).toBeNull());
		expect(h.toast.success).toHaveBeenCalledWith(m('social.friend.accepted'));

		await userEvent.click(screen.getByRole('button', { name: `${m('social.friend.decline')} · Finn` }));
		expect(h.friends.decline).toHaveBeenCalledWith('r2');
		await waitFor(() => expect(screen.queryByTestId('rail-requests')).toBeNull());
	});

	it('keeps the request and reports a failed answer', async () => {
		h.friends.getReceived.mockResolvedValue(page([request('r1', user('erin', 'Erin'))]));
		h.friends.suggestFriends.mockResolvedValue([]);
		h.friends.accept.mockRejectedValue(new Error('offline'));
		render(FriendsRail);

		await userEvent.click(
			await screen.findByRole('button', { name: `${m('social.friend.accept')} · Erin` })
		);
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('social.friend.failed')));
		expect(screen.getByText('Erin')).toBeInTheDocument();
	});

	it('shows nothing when both lists fail or are empty', async () => {
		h.friends.getReceived.mockRejectedValue(new Error('down'));
		h.friends.suggestFriends.mockRejectedValue(new Error('down'));
		const { container } = render(FriendsRail);
		await waitFor(() => expect(container.querySelector('[aria-hidden="true"]')).toBeNull());
		expect(screen.queryByTestId('rail-requests')).toBeNull();
		expect(screen.queryByTestId('rail-suggestions')).toBeNull();
	});
});

describe('PostList layout', () => {
	const post = (id: string): Post =>
		({
			id,
			author: { id: 'a', username: 'ann', displayName: 'Ann', avatarUrl: null, deleted: false },
			caption: `CAPTION_${id}`,
			location: null,
			playedAt: null,
			imageUrls: [],
			game: null,
			eventId: null,
			taggedUsers: [],
			likeCount: 0,
			commentCount: 0,
			likedByMe: false,
			isBookmarked: true,
			createdAt: new Date().toISOString(),
			editedAt: null
		}) as Post;
	const fetchPage = () => Promise.resolve({ items: [post('1')], nextCursor: null, hasMore: false });

	it('stacks by default and becomes a grid on request', async () => {
		const { unmount } = render(PostList, { fetchPage, emptyText: 'none' });
		const stack = (await screen.findByText('CAPTION_1')).closest('[data-layout]');
		expect(stack).toHaveAttribute('data-layout', 'stack');
		expect(stack?.className).not.toContain('md:grid');
		unmount();

		render(PostList, { fetchPage, emptyText: 'none', layout: 'grid' });
		const grid = (await screen.findByText('CAPTION_1')).closest('[data-layout]');
		expect(grid).toHaveAttribute('data-layout', 'grid');
		expect(grid?.className).toContain('md:grid-cols-2');
	});
});

describe('ReportSheet', () => {
	it('is a labelled dialog that sends the chosen reason', async () => {
		h.reports.report.mockResolvedValue(undefined);
		const onClose = vi.fn();
		render(ReportSheet, { targetType: 'post', targetId: 'p1', title: 'Report post', onClose });

		const dialog = screen.getByRole('dialog', { name: 'Report post' });
		const submit = within(dialog).getByRole('button', { name: m('social.report.submit') });
		expect(submit).toBeDisabled();
		await userEvent.click(within(dialog).getByLabelText(m('social.report.reasonSpam')));
		await userEvent.type(within(dialog).getByLabelText(m('social.report.details')), 'ads');
		await userEvent.click(submit);

		await waitFor(() => expect(h.reports.report).toHaveBeenCalledWith('post', 'p1', 'spam: ads'));
		expect(onClose).toHaveBeenCalled();
	});

	it('closes on Escape', async () => {
		const onClose = vi.fn();
		render(ReportSheet, { targetType: 'user', targetId: 'u1', title: 'Report', onClose });
		await userEvent.keyboard('{Escape}');
		expect(onClose).toHaveBeenCalled();
	});
});

describe('PostTagsEditor pickers', () => {
	it('opens the friend picker as a dialog and tags a friend', async () => {
		h.friends.getFriends.mockResolvedValue(page([user('bob', 'Bob')]));
		render(PostTagsEditor, { game: null, friends: [] });

		await userEvent.click(screen.getByRole('button', { name: new RegExp(m('social.create.tagFriends')) }));
		const dialog = await screen.findByRole('dialog', { name: m('social.create.friendsModalTitle') });
		await userEvent.click(await within(dialog).findByRole('button', { name: /Bob/ }));
		expect(within(dialog).getByRole('button', { name: /Bob/ })).toHaveAttribute('aria-pressed', 'true');

		await userEvent.click(within(dialog).getByRole('button', { name: m('social.create.done') }));
		await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
		expect(screen.getByText(m('social.create.friendsTagged', { count: 1 }))).toBeInTheDocument();
	});

	it('opens the game picker as a dialog that Escape closes', async () => {
		render(PostTagsEditor, { game: null, friends: [] });
		await userEvent.click(screen.getByRole('button', { name: new RegExp(m('social.create.tagGame')) }));
		expect(screen.getByRole('dialog', { name: m('social.create.gameModalTitle') })).toBeInTheDocument();
		await userEvent.keyboard('{Escape}');
		await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
	});
});
