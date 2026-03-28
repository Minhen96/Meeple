import { postsApi } from '$lib/api/posts';
import { gamesApi } from '$lib/api/games';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	const { user } = await parent();

	const [posts, collection] = await Promise.all([
		user ? postsApi.getUserPosts(user.id).catch(() => []) : [],
		gamesApi.getMyCollection().catch(() => [])
	]);

	return { user, posts, collection };
};
