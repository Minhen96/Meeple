import { render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiRequestError } from '$lib/api/client';
import { errorMessage, m } from '$lib/i18n';
import { setUser } from '$lib/stores/auth';
import type { FriendshipStatus, Post, User } from '$lib/types';
import FriendButton from './FriendButton.svelte';
import PostCard from './PostCard.svelte';

const h = vi.hoisted(() => ({
	toast: { success: vi.fn(), error: vi.fn() },
	posts: {
		likePost: vi.fn(),
		unlikePost: vi.fn(),
		bookmarkPost: vi.fn(),
		unbookmarkPost: vi.fn(),
		deletePost: vi.fn(),
		addComment: vi.fn()
	},
	friends: { sendRequest: vi.fn(), cancelTo: vi.fn() },
	reports: { report: vi.fn() },
	shareLink: vi.fn()
}));
vi.mock('svelte-sonner', () => ({ toast: h.toast }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/posts', () => ({ postsApi: h.posts }));
vi.mock('$lib/api/friends', () => ({ friendsApi: h.friends, reportsApi: h.reports }));
vi.mock('./share', () => ({
	shareLink: h.shareLink,
	postUrl: (id: string, origin: string) => `${origin}/posts/${id}`
}));

beforeEach(() => {
	for (const group of [h.toast, h.posts, h.friends, h.reports]) for (const fn of Object.values(group)) fn.mockReset();
	h.shareLink.mockReset();
	for (const fn of Object.values(h.posts)) fn.mockResolvedValue(undefined);
	setUser(null);
});

// ─── FriendButton ─────────────────────────────────────────────────────────────

describe('FriendButton', () => {
	function setup(status: FriendshipStatus) {
		const onChange = vi.fn();
		render(FriendButton, { userId: 'u2', status, onChange });
		return onChange;
	}

	it('"Friends" is a static label, not a button', () => {
		setup('friends');
		expect(screen.getByText(m('social.friend.friends'))).toBeInTheDocument();
		expect(screen.queryByRole('button')).toBeNull();
	});

	it('Add Friend sends a request and becomes Pending', async () => {
		h.friends.sendRequest.mockResolvedValue({ id: 'r1', status: 'PENDING' });
		const onChange = setup('none');
		await userEvent.click(screen.getByRole('button', { name: new RegExp(m('social.friend.add')) }));
		expect(h.friends.sendRequest).toHaveBeenCalledWith('u2');
		expect(onChange).toHaveBeenCalledWith('pending_sent');
		expect(h.toast.success).toHaveBeenCalledWith(m('social.friend.requestSent'));
		expect(await screen.findByRole('button', { name: m('social.friend.pending') })).toBeInTheDocument();
	});

	it('sending to someone who already asked me makes us friends', async () => {
		h.friends.sendRequest.mockResolvedValue({ id: 'r1', status: 'ACCEPTED' });
		const onChange = setup('none');
		await userEvent.click(screen.getByRole('button'));
		expect(onChange).toHaveBeenCalledWith('friends');
		expect(h.toast.success).toHaveBeenCalledWith(m('social.friend.accepted'));
		expect(await screen.findByText(m('social.friend.friends'))).toBeInTheDocument();
	});

	it('tapping Pending withdraws the request', async () => {
		h.friends.cancelTo.mockResolvedValue(undefined);
		const onChange = setup('pending_sent');
		await userEvent.click(screen.getByRole('button', { name: m('social.friend.pending') }));
		expect(h.friends.cancelTo).toHaveBeenCalledWith('u2');
		expect(onChange).toHaveBeenCalledWith('none');
		expect(h.toast.success).toHaveBeenCalledWith(m('social.friend.cancelled'));
	});

	it('Accept on a received request accepts it', async () => {
		h.friends.sendRequest.mockResolvedValue({ id: 'r1', status: 'ACCEPTED' });
		const onChange = setup('pending_received');
		await userEvent.click(screen.getByRole('button', { name: m('social.friend.accept') }));
		expect(onChange).toHaveBeenCalledWith('friends');
	});

	it('maps API errors to localized messages and keeps the state', async () => {
		h.friends.sendRequest.mockRejectedValue(new ApiRequestError('USER_BLOCKED', 'blocked', 403));
		const onChange = setup('none');
		await userEvent.click(screen.getByRole('button'));
		expect(h.toast.error).toHaveBeenCalledWith(errorMessage('USER_BLOCKED'));
		expect(onChange).not.toHaveBeenCalled();
		expect(screen.getByRole('button')).toBeEnabled();
	});

	it('falls back to a generic message for unknown failures', async () => {
		h.friends.sendRequest.mockRejectedValue(new Error('net'));
		setup('none');
		await userEvent.click(screen.getByRole('button'));
		expect(h.toast.error).toHaveBeenCalledWith(m('social.friend.failed'));
	});

	it('ignores double taps while a request is in flight', async () => {
		let resolve: (v: unknown) => void = () => {};
		h.friends.sendRequest.mockImplementation(() => new Promise((r) => (resolve = r)));
		setup('none');
		const btn = screen.getByRole('button');
		await userEvent.click(btn);
		expect(btn).toBeDisabled();
		await userEvent.click(btn);
		expect(h.friends.sendRequest).toHaveBeenCalledTimes(1);
		resolve({ status: 'PENDING' });
	});
});

// ─── PostCard ─────────────────────────────────────────────────────────────────

function makePost(overrides: Partial<Post> = {}): Post {
	return {
		id: 'p1',
		author: { id: 'author', username: 'ann', displayName: 'Ann', avatarUrl: null, deleted: false },
		caption: 'Great game night',
		location: null,
		playedAt: null,
		imageUrls: [],
		game: null,
		eventId: null,
		taggedUsers: [],
		likeCount: 0,
		commentCount: 0,
		likedByMe: false,
		isBookmarked: false,
		createdAt: new Date(Date.now() - 3600_000).toISOString(),
		editedAt: null,
		...overrides
	};
}

function renderPost(overrides: Partial<Post> = {}, onDeleted = vi.fn()) {
	const post = $state(makePost(overrides));
	render(PostCard, { post, onDeleted });
	return { post, onDeleted };
}

describe('PostCard', () => {
	it('renders author link, caption, game, tags, likes and comments', () => {
		renderPost({
			game: { id: 'g1', title: 'Catan' } as Post['game'],
			taggedUsers: [
				{ id: 't1', username: 'tim', displayName: null, avatarUrl: null },
				{ id: 't2', username: 'sue', displayName: 'Sue', avatarUrl: null }
			],
			likeCount: 3,
			commentCount: 5,
			location: 'Cafe',
			editedAt: '2026-01-01T00:00:00Z'
		});
		const card = screen.getByRole('article');
		expect(within(card).getByRole('link', { name: 'Ann' })).toHaveAttribute('href', '/profile/author');
		expect(card).toHaveTextContent('Great game night');
		expect(card).toHaveTextContent('Cafe');
		expect(card).toHaveTextContent(m('social.post.edited'));
		expect(within(card).getByRole('link', { name: m('social.post.played', { game: 'Catan' }) })).toHaveAttribute('href', '/library/g1');
		expect(within(card).getByRole('link', { name: 'tim' })).toHaveAttribute('href', '/profile/t1');
		expect(within(card).getByRole('link', { name: 'Sue' })).toBeInTheDocument();
		expect(card).toHaveTextContent(m('social.post.likeMany', { count: 3 }));
		expect(within(card).getByRole('link', { name: m('social.post.viewComments', { count: 5 }) })).toHaveAttribute('href', '/posts/p1');
	});

	it('deleted authors are not linked', () => {
		renderPost({ author: { id: 'a', username: 'x', displayName: 'X', avatarUrl: null, deleted: true }, likeCount: 1, commentCount: 1 });
		expect(screen.queryByRole('link', { name: 'X' })).toBeNull();
		expect(screen.getByText(m('social.post.likeOne'))).toBeInTheDocument();
		expect(screen.getByText(m('social.post.viewOneComment'))).toBeInTheDocument();
	});

	it('renders one image per URL with a pager when there are several', () => {
		renderPost({ imageUrls: ['https://i/1.webp', 'https://i/2.webp'] });
		const imgs = screen.getAllByRole('img', { name: /./ }).filter((i) => i.getAttribute('src')?.startsWith('https://i/'));
		expect(imgs.map((i) => i.getAttribute('src'))).toEqual(['https://i/1.webp', 'https://i/2.webp']);
		expect(imgs[0]).toHaveAccessibleName(m('social.post.image', { index: 1, count: 2 }));
	});

	it('like is optimistic and calls the API', async () => {
		const { post } = renderPost({ likeCount: 2 });
		await userEvent.click(screen.getByRole('button', { name: m('social.post.like') }));
		expect(h.posts.likePost).toHaveBeenCalledWith('p1');
		expect(post.likedByMe).toBe(true);
		expect(post.likeCount).toBe(3);
		const unlike = await screen.findByRole('button', { name: m('social.post.unlike') });
		expect(unlike).toHaveAttribute('aria-pressed', 'true');

		await userEvent.click(unlike);
		expect(h.posts.unlikePost).toHaveBeenCalledWith('p1');
		expect(post.likeCount).toBe(2);
	});

	it('rolls a failed like back and tells the user', async () => {
		h.posts.likePost.mockRejectedValue(new Error('net'));
		const { post } = renderPost({ likeCount: 2 });
		await userEvent.click(screen.getByRole('button', { name: m('social.post.like') }));
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('social.post.likeFailed')));
		expect(post).toMatchObject({ likedByMe: false, likeCount: 2 });
	});

	it('bookmark toggles with feedback and rolls back on failure', async () => {
		const { post } = renderPost();
		await userEvent.click(screen.getByRole('button', { name: m('social.post.bookmark') }));
		expect(h.posts.bookmarkPost).toHaveBeenCalledWith('p1');
		expect(h.toast.success).toHaveBeenCalledWith(m('social.post.saved'));
		await userEvent.click(await screen.findByRole('button', { name: m('social.post.unbookmark') }));
		expect(h.posts.unbookmarkPost).toHaveBeenCalledWith('p1');
		expect(h.toast.success).toHaveBeenLastCalledWith(m('social.post.unsaved'));

		h.posts.bookmarkPost.mockRejectedValue(new Error('x'));
		await userEvent.click(await screen.findByRole('button', { name: m('social.post.bookmark') }));
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('social.post.bookmarkFailed')));
		expect(post.isBookmarked).toBe(false);
	});

	it.each([
		['copied', 'success', 'social.post.linkCopied'],
		['failed', 'error', 'social.post.shareFailed']
	] as const)('share outcome %s shows a toast', async (outcome, kind, key) => {
		h.shareLink.mockResolvedValue(outcome);
		renderPost();
		await userEvent.click(screen.getByRole('button', { name: m('social.post.share') }));
		expect(h.shareLink).toHaveBeenCalledWith(`${location.origin}/posts/p1`, m('social.post.shareText'));
		expect(h.toast[kind]).toHaveBeenCalledWith(m(key));
	});

	it('a completed native share needs no toast', async () => {
		h.shareLink.mockResolvedValue('shared');
		renderPost();
		await userEvent.click(screen.getByRole('button', { name: m('social.post.share') }));
		expect(h.toast.success).not.toHaveBeenCalled();
		expect(h.toast.error).not.toHaveBeenCalled();
	});

	it('quick comment posts the trimmed body, bumps the count and clears the input', async () => {
		const { post } = renderPost();
		const input = screen.getByRole('textbox', { name: m('social.post.addComment') });
		expect(screen.queryByRole('button', { name: m('social.post.postComment') })).toBeNull();
		await userEvent.type(input, '  nice!  ');
		await userEvent.click(screen.getByRole('button', { name: m('social.post.postComment') }));
		expect(h.posts.addComment).toHaveBeenCalledWith('p1', 'nice!');
		await waitFor(() => expect(input).toHaveValue(''));
		expect(post.commentCount).toBe(1);
	});

	it('a failed quick comment keeps the text', async () => {
		h.posts.addComment.mockRejectedValue(new Error('x'));
		renderPost();
		const input = screen.getByRole('textbox');
		await userEvent.type(input, 'hello{Enter}');
		await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('social.post.commentFailed')));
		expect(input).toHaveValue('hello');
	});

	it('long captions get a "more" toggle', async () => {
		renderPost({ caption: 'x'.repeat(200) });
		await userEvent.click(screen.getByRole('button', { name: new RegExp(m('social.post.readMore')) }));
		expect(screen.queryByRole('button', { name: new RegExp(m('social.post.readMore')) })).toBeNull();
	});

	describe('menu', () => {
		it('non-authors can report, not edit or delete', async () => {
			setUser({ id: 'someone-else' } as User);
			renderPost();
			await userEvent.click(screen.getByRole('button', { name: m('social.post.more') }));
			const menu = screen.getByRole('menu');
			expect(within(menu).queryByRole('menuitem', { name: new RegExp(m('social.post.delete')) })).toBeNull();
			await userEvent.click(within(menu).getByRole('menuitem', { name: new RegExp(m('social.post.report')) }));
			expect(screen.queryByRole('menu')).toBeNull();
			expect(await screen.findByText(m('social.report.titlePost'))).toBeInTheDocument();
		});

		it('authors can edit within 48h and delete after confirming', async () => {
			setUser({ id: 'author' } as User);
			const { onDeleted } = renderPost();
			await userEvent.click(screen.getByRole('button', { name: m('social.post.more') }));
			expect(screen.getByRole('menuitem', { name: new RegExp(m('social.post.edit')) })).toHaveAttribute('href', '/posts/p1?edit=1');
			await userEvent.click(screen.getByRole('menuitem', { name: new RegExp(m('social.post.delete')) }));
			const dialog = await screen.findByRole('dialog', { name: m('social.post.deleteTitle') });
			await userEvent.click(within(dialog).getByRole('button', { name: m('common.delete') }));
			expect(h.posts.deletePost).toHaveBeenCalledWith('p1');
			await waitFor(() => expect(onDeleted).toHaveBeenCalledWith('p1'));
			expect(h.toast.success).toHaveBeenCalledWith(m('social.post.deleted'));
		});

		it('authors cannot edit after 48h; a failed delete reports an error; cancel closes', async () => {
			setUser({ id: 'author' } as User);
			h.posts.deletePost.mockRejectedValue(new Error('x'));
			const { onDeleted } = renderPost({ createdAt: new Date(Date.now() - 49 * 3600_000).toISOString() });
			const more = screen.getByRole('button', { name: m('social.post.more') });
			await userEvent.click(more);
			expect(screen.queryByRole('menuitem', { name: new RegExp(m('social.post.edit')) })).toBeNull();
			// Backdrop closes the menu.
			await userEvent.click(screen.getByRole('button', { name: m('common.cancel') }));
			expect(screen.queryByRole('menu')).toBeNull();

			await userEvent.click(more);
			await userEvent.click(screen.getByRole('menuitem', { name: new RegExp(m('social.post.delete')) }));
			let dialog = await screen.findByRole('dialog');
			await userEvent.click(within(dialog).getByRole('button', { name: m('common.cancel') }));
			await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());

			await userEvent.click(more);
			await userEvent.click(screen.getByRole('menuitem', { name: new RegExp(m('social.post.delete')) }));
			dialog = await screen.findByRole('dialog');
			await userEvent.click(within(dialog).getByRole('button', { name: m('common.delete') }));
			await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(m('social.post.deleteFailed')));
			expect(onDeleted).not.toHaveBeenCalled();
		});
	});
});
