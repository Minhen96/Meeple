import { postsApi } from '$lib/api/posts';
import { throwLoadError } from '$lib/api/load';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user } = await parent();
	try {
		const [post, comments] = await Promise.all([
			postsApi.getPost(params.postId, { fetch }),
			postsApi.getComments(params.postId, 0, 20, { fetch }).catch(() => [])
		]);
		return { user, post, comments };
	} catch (err) {
		throwLoadError(err, url, 'Post not found');
	}
};
