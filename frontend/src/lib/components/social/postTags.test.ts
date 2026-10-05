import { describe, expect, it } from 'vitest';
import {
	MAX_TAGGED_FRIENDS,
	moveItem,
	tagUpdatePayload,
	toggleTaggedFriend,
	type TaggedFriend
} from './postTags';

const friend = (id: string): TaggedFriend => ({
	id,
	username: id,
	displayName: null,
	avatarUrl: null
});

describe('moveItem', () => {
	it('moves forward and backward without mutating the input', () => {
		const list = ['a', 'b', 'c', 'd'];
		expect(moveItem(list, 0, 2)).toEqual(['b', 'c', 'a', 'd']);
		expect(moveItem(list, 3, 1)).toEqual(['a', 'd', 'b', 'c']);
		expect(list).toEqual(['a', 'b', 'c', 'd']);
	});

	it('clamps the target and ignores invalid sources', () => {
		expect(moveItem(['a', 'b', 'c'], 0, 99)).toEqual(['b', 'c', 'a']);
		expect(moveItem(['a', 'b', 'c'], 2, -5)).toEqual(['c', 'a', 'b']);
		expect(moveItem(['a', 'b'], 5, 0)).toEqual(['a', 'b']);
		expect(moveItem(['a', 'b'], 1, 1)).toEqual(['a', 'b']);
	});
});

describe('toggleTaggedFriend', () => {
	it('adds and removes by id', () => {
		const added = toggleTaggedFriend([], friend('x'));
		expect(added.map((f) => f.id)).toEqual(['x']);
		expect(toggleTaggedFriend(added, friend('x'))).toEqual([]);
	});

	it('stops at the backend limit', () => {
		const full = Array.from({ length: MAX_TAGGED_FRIENDS }, (_, i) => friend(String(i)));
		expect(toggleTaggedFriend(full, friend('extra'))).toHaveLength(MAX_TAGGED_FRIENDS);
		expect(toggleTaggedFriend(full, friend('0'))).toHaveLength(MAX_TAGGED_FRIENDS - 1);
	});
});

describe('tagUpdatePayload', () => {
	const original = { game: { id: 'g1' }, taggedUsers: [{ id: 'a' }, { id: 'b' }] };

	it('is empty when nothing changed (friend order ignored)', () => {
		expect(
			tagUpdatePayload(original, { game: { id: 'g1' }, friends: [{ id: 'b' }, { id: 'a' }] })
		).toEqual({});
	});

	it('sends gameId for a new game and clearGame for a removed one', () => {
		expect(
			tagUpdatePayload(original, { game: { id: 'g2' }, friends: original.taggedUsers })
		).toEqual({
			gameId: 'g2'
		});
		expect(tagUpdatePayload(original, { game: null, friends: original.taggedUsers })).toEqual({
			clearGame: true
		});
		expect(tagUpdatePayload({ game: null, taggedUsers: [] }, { game: null, friends: [] })).toEqual(
			{}
		);
	});

	it('sends the full friend list when the set changed, including clearing it', () => {
		expect(tagUpdatePayload(original, { game: { id: 'g1' }, friends: [{ id: 'c' }] })).toEqual({
			taggedUserIds: ['c']
		});
		expect(tagUpdatePayload(original, { game: { id: 'g1' }, friends: [] })).toEqual({
			taggedUserIds: []
		});
	});
});
