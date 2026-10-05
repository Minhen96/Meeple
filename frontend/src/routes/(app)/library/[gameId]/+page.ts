import { gamesApi } from '$lib/api/games';
import { throwLoadError } from '$lib/api/load';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params, parent, fetch, url }) => {
	const { user } = await parent();
	try {
		const [game, collection] = await Promise.all([
			gamesApi.getGame(params.gameId, { fetch }),
			gamesApi.getMyCollection({ fetch }).catch(() => [])
		]);
		const myEntry = collection.find((ug) => ug.game.id === params.gameId) ?? null;
		return { user, game, myEntry };
	} catch (err) {
		throwLoadError(err, url, 'Game not found');
	}
};
