import { friendsApi } from '$lib/api/friends';
import { throwLoadError } from '$lib/api/load';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch, url }) => {
	// Wait for the root layout (which may refresh the session) before fetching.
	await parent();
	try {
		const res = await friendsApi.getFriends(0, 20, { fetch });
		return {
			friends: res.data,
			meta: res.meta
		};
	} catch (err) {
		throwLoadError(err, url, 'Friends not found');
	}
};
