// Search overlay: clearing the query invalidates a search still in flight, so its late results
// never reappear (e.g. under the next query while that one is still debouncing).
import { act, render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { page } from '$app/stores';
import { m } from '$lib/i18n';
import type { SearchResults } from '$lib/types';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({ search: vi.fn() }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/friends', () => ({ searchApi: { search: h.search } }));

const hits: SearchResults = {
	games: [{ id: 'g1', title: 'STALE_GAME', thumbnailUrl: null } as SearchResults['games'][number]],
	users: [],
	events: []
};

function setUrl(href: string) {
	page.update((p) => ({ ...p, url: new URL(href, 'http://localhost') }));
}

beforeEach(() => {
	h.search.mockReset();
});

afterEach(() => {
	setUrl('/');
});

describe('search overlay', () => {
	it('ignores results that arrive after the query was cleared', async () => {
		let resolve: (r: SearchResults) => void = () => {};
		h.search.mockReturnValue(new Promise<SearchResults>((r) => (resolve = r)));
		setUrl('/search?q=catan');
		render(Page);
		expect(h.search).toHaveBeenCalledWith('catan', { limit: 3 });

		await userEvent.click(screen.getByRole('button', { name: m('social.search.clearInput') }));
		await act(() => resolve(hits));

		expect(screen.getByRole('searchbox')).toHaveValue('');

		// typing a new query shows the loading state, not the cleared query's late results
		h.search.mockReturnValue(new Promise<SearchResults>(() => {}));
		await userEvent.type(screen.getByRole('searchbox'), 'p');
		expect(screen.getByRole('searchbox')).toHaveValue('p');
		expect(screen.queryByText('STALE_GAME')).toBeNull();
	});
});
