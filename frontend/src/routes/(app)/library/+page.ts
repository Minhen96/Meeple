import { gamesApi } from '$lib/api/games';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent, fetch }) => {
	const { user } = await parent();
	const collection = await gamesApi.getMyCollection({ fetch }).catch(() => []);
	return { user, collection };
};
