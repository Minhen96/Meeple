// Post detail edit mode: the draft is seeded once when editing starts; unrelated updates of the
// post (a like, a new comment) must neither reset the draft nor reopen a closed editor.
import { render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { m } from '$lib/i18n';
import type { Post } from '$lib/types';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({
	posts: {
		likePost: vi.fn(),
		unlikePost: vi.fn(),
		addComment: vi.fn(),
		updatePost: vi.fn(),
		getComments: vi.fn()
	}
}));
vi.mock('svelte-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/posts', () => ({ postsApi: h.posts }));

function makePost(): Post {
	return {
		id: 'p1',
		author: { id: 'me', username: 'me', displayName: 'Me', avatarUrl: null, deleted: false },
		caption: 'Original caption',
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
		editedAt: null
	};
}

const data = () =>
	({
		user: { id: 'me', username: 'me' },
		post: makePost(),
		comments: [],
		commentsCursor: null,
		editRequested: true
	}) as never;

const captionBox = () => screen.getByDisplayValue(/caption/i) as HTMLTextAreaElement;

beforeEach(() => {
	for (const fn of Object.values(h.posts)) fn.mockReset();
	h.posts.likePost.mockResolvedValue(undefined);
});

describe('post detail edit mode', () => {
	it('keeps the typed draft when the post is liked while editing', async () => {
		render(Page, { data: data() });
		const box = captionBox();
		expect(box.value).toBe('Original caption');

		await userEvent.clear(box);
		await userEvent.type(box, 'My new caption');
		await userEvent.click(screen.getByRole('button', { name: m('social.post.like') }));
		await waitFor(() => expect(h.posts.likePost).toHaveBeenCalledWith('p1'));

		expect(captionBox().value).toBe('My new caption');
	});

	it('does not reopen the editor after cancelling when the post changes', async () => {
		render(Page, { data: data() });
		await userEvent.click(screen.getByRole('button', { name: m('common.cancel') }));
		await waitFor(() => expect(screen.queryByDisplayValue('Original caption')).toBeNull());
		await userEvent.click(screen.getByRole('button', { name: m('social.post.like') }));
		await waitFor(() => expect(h.posts.likePost).toHaveBeenCalled());
		expect(screen.queryByDisplayValue('Original caption')).toBeNull();
	});
});
