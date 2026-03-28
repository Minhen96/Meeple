import { gamesApi } from '$lib/api/games';
import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent }) => {
	const { user } = await parent();
	try {
		const [game, collection] = await Promise.all([
			gamesApi.getGame(params.gameId),
			gamesApi.getMyCollection().catch(() => [])
		]);
		const myEntry = collection.find((ug) => ug.game.id === params.gameId) ?? null;
		return { user, game, myEntry };
	} catch {
		throw error(404, 'Game not found');
	}
};
