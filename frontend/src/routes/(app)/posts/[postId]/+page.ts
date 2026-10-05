import { postsApi } from '$lib/api/posts';
import { ApiRequestError } from '$lib/api/client';
import { throwLoadError } from '$lib/api/load';
import type { Comment, CursorPage, Post } from '$lib/types';
import type { PageLoad } from './$types';

/** Comments per page ("Load more comments" fetches the next one). */
const COMMENT_PAGE_SIZE = 20;

const NO_COMMENTS: CursorPage<Comment> = { items: [], nextCursor: null, hasMore: false };

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user } = await parent();
	try {
		const [post, comments] = await Promise.all([
			postsApi.getPost(params.postId, { fetch }),
			postsApi
				.getComments(params.postId, null, COMMENT_PAGE_SIZE, { fetch })
				.catch((): CursorPage<Comment> => NO_COMMENTS)
		]);
		return {
			user,
			post: post as Post | null,
			comments: comments.items,
			commentsCursor: comments.hasMore ? comments.nextCursor : null,
			editRequested: url.searchParams.get('edit') === '1'
		};
	} catch (err) {
		// Deleted, hidden by a block, or never existed: the page shows "This post has been removed."
		if (err instanceof ApiRequestError && err.status === 404) {
			return {
				user,
				post: null,
				comments: [] as Comment[],
				commentsCursor: null,
				editRequested: false
			};
		}
		throwLoadError(err, url, 'Post not found');
	}
};
