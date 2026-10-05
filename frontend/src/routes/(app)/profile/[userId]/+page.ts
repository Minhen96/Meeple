import { usersApi } from '$lib/api/users';
import { friendsApi } from '$lib/api/friends';
import { gamesApi } from '$lib/api/games';
import { postsApi } from '$lib/api/posts';
import { throwLoadError } from '$lib/api/load';
import { redirect } from '@sveltejs/kit';
import type { UserGame } from '$lib/types';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user: me } = await parent();

	// Your own profile lives at /profile
	if (me && params.userId === me.id) {
		redirect(302, '/profile');
	}

	// 404 when the user does not exist, is deleted, or either side blocked the other
	let user;
	let friendStatus;
	try {
		[user, friendStatus] = await Promise.all([
			usersApi.getUser(params.userId, { fetch }),
			friendsApi.getStatus(params.userId, { fetch })
		]);
	} catch (err) {
		throwLoadError(err, url, 'User not found');
	}

	const isFriend = friendStatus.status === 'FRIENDS';
	const [posts, taggedPosts, collection, stats] = await Promise.all([
		postsApi.getUserPosts(params.userId, 0, 30, { fetch }).catch(() => []),
		// null renders the Tagged tab's unavailable state
		postsApi
			.getTaggedPosts(params.userId, null, 30, { fetch })
			.then((page) => page.items)
			.catch(() => null),
		isFriend
			? gamesApi.getUserCollection(params.userId, { fetch }).catch((): UserGame[] => [])
			: Promise.resolve<UserGame[]>([]),
		usersApi.getStats(params.userId, { fetch }).catch(() => null)
	]);

	return { user, friendStatus, posts, taggedPosts, collection, stats, isFriend };
};
