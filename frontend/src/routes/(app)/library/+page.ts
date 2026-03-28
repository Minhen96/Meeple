import { gamesApi } from '$lib/api/games';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ parent }) => {
	const { user } = await parent();
	const collection = await gamesApi.getMyCollection().catch(() => []);
	return { user, collection };
};
