import { postsApi } from '$lib/api/posts';
import { ApiRequestError } from '$lib/api/client';
import { throwLoadError } from '$lib/api/load';
import type { Comment, Post } from '$lib/types';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user } = await parent();
	try {
		const [post, comments] = await Promise.all([
			postsApi.getPost(params.postId, { fetch }),
			postsApi.getComments(params.postId, 0, 50, { fetch }).catch((): Comment[] => [])
		]);
		return {
			user,
			post: post as Post | null,
			comments,
			editRequested: url.searchParams.get('edit') === '1'
		};
	} catch (err) {
		// Deleted, hidden by a block, or never existed: the page shows "This post has been removed."
		if (err instanceof ApiRequestError && err.status === 404) {
			return {
				user,
				post: null,
				comments: [] as Comment[],
				editRequested: false
			};
		}
		throwLoadError(err, url, 'Post not found');
	}
};
