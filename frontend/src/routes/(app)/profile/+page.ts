import { postsApi } from '$lib/api/posts';
import { gamesApi } from '$lib/api/games';
import { friendsApi } from '$lib/api/friends';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch }) => {
	const { user } = await parent();
	// The root layout already redirects anonymous users; this narrows the type.
	if (!user) redirect(303, '/auth/login');

	const [posts, collection, activity, friends] = await Promise.all([
		postsApi.getUserPosts(user.id, 0, 20, { fetch }).catch(() => []),
		gamesApi.getMyCollection({ fetch }).catch(() => []),
		gamesApi.getActivity({ fetch }).catch(() => []),
		friendsApi.getFriends(0, 1, { fetch }).catch(() => ({ data: [], meta: { total: 0 } }))
	]);

	return { user, posts, collection, activity, friendCount: friends.meta.total };
};
