/** Case- and accent-insensitive match of a friend's display name or username against `query`. */
export function filterFriends<T extends { username: string; displayName: string | null }>(
	friends: readonly T[],
	query: string
): T[] {
	const needle = normalize(query.trim());
	if (!needle) return [...friends];
	return friends.filter(
		(f) => normalize(f.username).includes(needle) || normalize(f.displayName ?? '').includes(needle)
	);
}

function normalize(value: string): string {
	return value
		.normalize('NFD')
		.replace(/\p{Diacritic}/gu, '')
		.toLowerCase();
}
