import { usersApi } from '$lib/api/users';
import { friendsApi } from '$lib/api/friends';
import { gamesApi } from '$lib/api/games';
import { throwLoadError } from '$lib/api/load';
import { redirect } from '@sveltejs/kit';
import type { ActivityLog, UserGame } from '$lib/types';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user: me } = await parent();

	// Redirect to own profile page instead of showing Add Friend button
	if (me && params.userId === me.id) {
		redirect(302, '/profile');
	}

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

	let collection: UserGame[] = [];
	let activity: ActivityLog[] = [];
	if (friendStatus.status === 'FRIENDS') {
		[collection, activity] = await Promise.all([
			gamesApi.getUserCollection(params.userId, { fetch }).catch(() => []),
			gamesApi.getUserActivity(params.userId, { fetch }).catch(() => [])
		]);
	}

	return { user, friendStatus, collection, activity };
};
