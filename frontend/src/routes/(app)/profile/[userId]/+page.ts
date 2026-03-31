import { usersApi } from '$lib/api/users';
import { friendsApi } from '$lib/api/friends';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent }) => {
	const { user: me } = await parent();

	// Redirect to own profile page instead of showing Add Friend button
	if (me && params.userId === me.id) {
		redirect(302, '/profile');
	}

	const [user, friendStatus] = await Promise.all([
		usersApi.getUser(params.userId),
		friendsApi.getStatus(params.userId)
	]);
	return { user, friendStatus };
};
