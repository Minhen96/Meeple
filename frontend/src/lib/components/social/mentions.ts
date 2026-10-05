/**
 * `@username` mentions in comments, matching the backend's MentionParser: 3–30 of
 * [A-Za-z0-9_], not preceded by a username character (so e-mail addresses are not mentions).
 */
const MENTION = /(?<![A-Za-z0-9_])@([A-Za-z0-9_]{3,30})(?![A-Za-z0-9_])/g;

export type TextSegment =
	| { type: 'text'; value: string }
	| { type: 'mention'; value: string; username: string };

/** Splits text into plain and mention segments for highlighted rendering (no HTML involved). */
export function tokenizeMentions(text: string): TextSegment[] {
	const segments: TextSegment[] = [];
	let last = 0;
	for (const match of text.matchAll(MENTION)) {
		const start = match.index ?? 0;
		if (start > last) segments.push({ type: 'text', value: text.slice(last, start) });
		segments.push({
			type: 'mention',
			value: match[0],
			username: match[1].toLowerCase()
		});
		last = start + match[0].length;
	}
	if (last < text.length) segments.push({ type: 'text', value: text.slice(last) });
	return segments;
}
