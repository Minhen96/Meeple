// Post tagging and photo ordering helpers shared by post create and post edit
// (FEATURES_COMPLETE 5.4: game + friends can be changed while editing; images cannot).
import type { UpdatePostPayload } from '$lib/api/posts';

/** Backend limit on tagged users per post (UpdatePostRequest / CreatePostRequest). */
export const MAX_TAGGED_FRIENDS = 20;

/** A game that can be tagged: only games already in the catalogue (with an id). */
export interface TaggedGame {
	id: string;
	title: string;
	thumbnailUrl: string | null;
}

/** A tagged friend: the fields both `User` and `Post.taggedUsers` provide. */
export interface TaggedFriend {
	id: string;
	username: string;
	displayName: string | null;
	avatarUrl: string | null;
}

/** Add or remove `friend`; adding beyond MAX_TAGGED_FRIENDS is ignored. */
export function toggleTaggedFriend(list: TaggedFriend[], friend: TaggedFriend): TaggedFriend[] {
	if (list.some((f) => f.id === friend.id)) return list.filter((f) => f.id !== friend.id);
	if (list.length >= MAX_TAGGED_FRIENDS) return list;
	return [...list, friend];
}

/**
 * The tag part of a PUT /posts/{id} body: only what changed. A removed game sends
 * `clearGame: true`; a changed friend set (order ignored) sends the full replacement list.
 */
export function tagUpdatePayload(
	original: { game: { id: string } | null; taggedUsers: { id: string }[] },
	edited: { game: { id: string } | null; friends: { id: string }[] }
): Pick<UpdatePostPayload, 'gameId' | 'clearGame' | 'taggedUserIds'> {
	const payload: Pick<UpdatePostPayload, 'gameId' | 'clearGame' | 'taggedUserIds'> = {};
	if ((original.game?.id ?? null) !== (edited.game?.id ?? null)) {
		if (edited.game) payload.gameId = edited.game.id;
		else payload.clearGame = true;
	}
	const before = original.taggedUsers.map((u) => u.id).sort();
	const after = edited.friends.map((u) => u.id).sort();
	if (before.length !== after.length || before.some((id, i) => id !== after[i])) {
		payload.taggedUserIds = edited.friends.map((u) => u.id);
	}
	return payload;
}

/** Move the item at `from` to index `to` (clamped); returns a new array. */
export function moveItem<T>(list: readonly T[], from: number, to: number): T[] {
	const next = [...list];
	if (from < 0 || from >= list.length) return next;
	const target = Math.max(0, Math.min(list.length - 1, to));
	if (target === from) return next;
	const [item] = next.splice(from, 1);
	next.splice(target, 0, item);
	return next;
}
