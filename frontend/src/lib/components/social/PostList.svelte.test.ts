// PostList: a replaced pager (new fetchPage source) must never write its late page over the
// refreshed list.
import { render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import type { CursorPage, Post } from '$lib/types';
import PostList from './PostList.svelte';

vi.mock('svelte-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));

function post(id: string): Post {
	return {
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
		isBookmarked: false,
		createdAt: new Date().toISOString(),
		editedAt: null
	};
}

describe('PostList', () => {
	it('ignores a page that arrives for the previous source after the list was refreshed', async () => {
		let resolveOld: (page: CursorPage<Post>) => void = () => {};
		const oldSource = vi.fn(
			() => new Promise<CursorPage<Post>>((resolve) => (resolveOld = resolve))
		);
		const newSource = vi.fn(async (): Promise<CursorPage<Post>> => ({
			items: [],
			nextCursor: null,
			hasMore: false
		}));

		const { rerender } = render(PostList, { fetchPage: oldSource, emptyText: 'EMPTY_NEW' });
		expect(oldSource).toHaveBeenCalledTimes(1);

		await rerender({ fetchPage: newSource, emptyText: 'EMPTY_NEW' });
		await waitFor(() => expect(screen.getByText('EMPTY_NEW')).toBeInTheDocument());

		resolveOld({ items: [post('stale')], nextCursor: null, hasMore: false });
		await new Promise((r) => setTimeout(r, 0));

		expect(screen.queryByText('CAPTION_stale')).toBeNull();
		expect(screen.getByText('EMPTY_NEW')).toBeInTheDocument();
	});
});
