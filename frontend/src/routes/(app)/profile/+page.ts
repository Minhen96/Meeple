import { postsApi } from '$lib/api/posts';
import { gamesApi } from '$lib/api/games';
import { friendsApi } from '$lib/api/friends';
import { usersApi } from '$lib/api/users';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch }) => {
	const { user } = await parent();
	// The root layout already redirects anonymous users; this narrows the type.
	if (!user) redirect(303, '/auth/login');

	// Every section degrades on its own: a failing list renders its empty state.
	const [posts, collection, friends, stats] = await Promise.all([
		postsApi.getUserPosts(user.id, 0, 30, { fetch }).catch(() => []),
		gamesApi.getMyCollection({ fetch }).catch(() => []),
		friendsApi.getFriends(0, 1, { fetch }).catch(() => null),
		usersApi.getStats(user.id, { fetch }).catch(() => null)
	]);

	return { user, posts, collection, friendCount: friends?.meta.total ?? null, stats };
};
