/**
 * Lint-style guard against hard-coded user-facing English in Svelte templates.
 *
 * For every .svelte file under src/, the <script> and <style> blocks are removed and the
 * `{...}` expressions are split from the markup, then it reports:
 *  - text nodes containing a word of 3+ Latin letters,
 *  - user-facing attributes (placeholder, aria-label, title, alt, label) with literal text, and
 *  - capitalized prose string literals inside template expressions (`{busy ? 'Saving…' : …}`).
 * Anything reported must either move to an m() key or be added to ALLOWLIST with a reason.
 *
 * This is a heuristic, not a parser: strings built in <script> (toasts, error fallbacks)
 * are not covered and still need review.
 */
import { describe, expect, it } from 'vitest';

/** Every .svelte file under src/, as raw source text (Vite glob import). */
const SOURCES = import.meta.glob<string>('/src/**/*.svelte', {
	query: '?raw',
	import: 'default',
	eager: true
});

/** Literal text allowed in templates: brand names, proper nouns and non-language tokens. */
const ALLOWLIST: ReadonlySet<string> = new Set([
	'Meeple', // brand name
	'— Meeple', // brand suffix of <title>
	'BoardGameGeek', // proper noun
	'BGG', // proper noun (abbreviation)
	'DELETE', // literal confirmation token the API expects (errors.confirmationRequired)
	'Gloomhaven', // game title (proper noun)
	'Escape', // KeyboardEvent.key values compared in inline handlers
	'Enter'
]);

/** Attributes whose literal values are shown to (or read out for) the user. */
const TEXT_ATTRIBUTES = ['placeholder', 'aria-label', 'title', 'alt', 'label', 'aria-description'];

/** A quoted literal that reads like English UI copy: "Save", 'Load more', "Try again." */
const PROSE_LITERAL = /(["'`])([A-Z][a-z]{2,}(?:[ -][A-Za-z'’]+)*[.!?…]?)\1/g;

/**
 * Split markup into the text outside `{...}` expressions (each expression becomes a space)
 * and the expressions themselves. Handles nesting and braces inside quoted strings.
 */
function splitExpressions(markup: string): {
	text: string;
	expressions: string[];
} {
	let text = '';
	let expr = '';
	const expressions: string[] = [];
	let depth = 0;
	let quote: string | null = null;
	for (let i = 0; i < markup.length; i++) {
		const ch = markup[i];
		if (depth === 0) {
			if (ch === '{') {
				depth = 1;
				text += ' ';
			} else text += ch;
			continue;
		}
		if (quote) {
			expr += ch;
			if (ch === '\\') expr += markup[++i] ?? '';
			else if (ch === quote) quote = null;
			continue;
		}
		if (ch === '"' || ch === "'" || ch === '`') quote = ch;
		else if (ch === '{') depth++;
		else if (ch === '}' && --depth === 0) {
			expressions.push(expr);
			expr = '';
			continue;
		}
		expr += ch;
	}
	return { text, expressions };
}

function findUntranslated(source: string): string[] {
	const { text: markup, expressions } = splitExpressions(
		source
			.replace(/<script[\s\S]*?<\/script>/g, '')
			.replace(/<style[\s\S]*?<\/style>/g, '')
			.replace(/<!--[\s\S]*?-->/g, '')
	);
	const hits: string[] = [];
	const isWordy = (text: string) => /[A-Za-z]{3,}/.test(text) && !ALLOWLIST.has(text);

	for (const match of markup.matchAll(/<([^<>]*)>([^<>]+)(?=<)/g)) {
		// Material Symbols render icon names as ligature text, not words.
		if (/^[a-z]/.test(match[1]) && match[1].includes('material-symbols')) continue;
		const text = match[2]
			.replace(/\s+/g, ' ')
			.replace(/&nbsp;/g, ' ')
			.trim();
		if (text && isWordy(text)) hits.push(text);
	}
	const attrs = TEXT_ATTRIBUTES.join('|');
	for (const match of markup.matchAll(new RegExp(`\\s(?:${attrs})="([^"]*)"`, 'g'))) {
		const text = match[1].trim();
		if (text && isWordy(text)) hits.push(text);
	}
	for (const expression of expressions) {
		for (const match of expression.matchAll(PROSE_LITERAL)) {
			if (!ALLOWLIST.has(match[2])) hits.push(match[2]);
		}
	}
	return hits;
}

describe('untranslated template text', () => {
	it('detects text nodes, attributes and prose literals but ignores scripts and icons', () => {
		const sample = `<script>const a = '<b>Hello there</b>';</script>
<p>Hello world</p><p>{m('x.y')}</p><input placeholder="Type here" />
<b>{busy ? 'Saving…' : m('common.save')}</b><i class={on ? 'bg-primary' : ''}></i>
<span aria-label={m('a.b')}>Meeple</span><span class="material-symbols-outlined">close</span>
<style>p { color: red; }</style>`;
		expect(findUntranslated(sample)).toEqual(['Hello world', 'Type here', 'Saving…']);
	});

	it('finds no hard-coded English in any .svelte file', () => {
		const files = Object.entries(SOURCES);
		expect(files.length).toBeGreaterThan(50);
		const offenders: string[] = [];
		for (const [file, source] of files) {
			for (const hit of findUntranslated(source)) offenders.push(`${file}: ${hit}`);
		}
		expect(offenders).toEqual([]);
	});
});
