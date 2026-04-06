import type { PageLoad } from './$types';
import { friendsApi } from '$lib/api/friends';

export const load: PageLoad = async () => {
	const res = await friendsApi.getFriends();
	return {
		friends: res.data,
		meta: res.meta
	};
};
