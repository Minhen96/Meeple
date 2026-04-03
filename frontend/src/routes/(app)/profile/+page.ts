import { postsApi } from '$lib/api/posts';
import { gamesApi } from '$lib/api/games';
import { friendsApi } from '$lib/api/friends';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	const { user } = await parent();

	const [posts, collection, activity, friends] = await Promise.all([
		user ? postsApi.getUserPosts(user.id).catch(() => []) : [],
		gamesApi.getMyCollection().catch(() => []),
		gamesApi.getActivity().catch(() => []),
		friendsApi.getFriends(0, 1).catch(() => ({ data: [], meta: { total: 0 } }))
	]);

	return { user, posts, collection, activity, friendCount: friends.meta.total };
};
