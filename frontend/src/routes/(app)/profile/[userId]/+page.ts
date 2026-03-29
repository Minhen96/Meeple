import { usersApi } from '$lib/api/users';
import { friendsApi } from '$lib/api/friends';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params }) => {
	const [user, friendStatus] = await Promise.all([
		usersApi.getUser(params.userId),
		friendsApi.getStatus(params.userId)
	]);
	return { user, friendStatus };
};
