import { postsApi } from '$lib/api/posts';
import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent }) => {
	const { user } = await parent();
	try {
		const [post, comments] = await Promise.all([
			postsApi.getPost(params.postId),
			postsApi.getComments(params.postId).catch(() => [])
		]);
		return { user, post, comments };
	} catch {
		throw error(404, 'Post not found');
	}
};
