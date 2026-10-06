// Library tabs with deep links (?tab= / ?filter=): the URL picks the initial tab, but a tab chosen
// by hand sticks and is written back to the URL.
import { render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { get } from 'svelte/store';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { goto } from '$app/navigation';
// The test stub behind $app/stores (writable here, so tests can simulate navigation).
import { page } from '../../../test/stubs/app-stores';
import { m } from '$lib/i18n';
import { defaultState, libraryStore } from '$lib/stores/library';
import Page from './+page.svelte';

const h = vi.hoisted(() => ({
	games: { browse: vi.fn(), search: vi.fn(), updateCollection: vi.fn() }
}));
vi.mock('svelte-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/games', () => ({ gamesApi: h.games }));

function setUrl(href: string) {
	page.update((p) => ({ ...p, url: new URL(href, 'http://localhost') }));
}

const tab = (key: Parameters<typeof m>[0]) => screen.getByRole('button', { name: m(key) });

beforeEach(() => {
	libraryStore.set(defaultState);
	h.games.browse.mockResolvedValue({ ...defaultState.gamesPage, totalElements: 1, content: [] });
	h.games.search.mockResolvedValue([]);
	vi.mocked(goto).mockReset();
	// A real navigation updates $page; the stub does the same.
	vi.mocked(goto).mockImplementation(async (to: unknown) => {
		setUrl(String(to));
	});
	vi.stubGlobal(
		'IntersectionObserver',
		class {
			observe() {}
			disconnect() {}
		}
	);
	vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
	setUrl('/library');
});

afterEach(() => {
	vi.unstubAllGlobals();
	vi.restoreAllMocks();
});

const render_ = () => render(Page, { props: { data: { collection: [] } as never } });

describe('library tabs and deep links', () => {
	it('opens the deep-linked tab, then lets the user switch away and keeps the URL in sync', async () => {
		setUrl('/library?tab=wishlist');
		render_();
		await waitFor(() => expect(tab('library.tab.wishlist')).toHaveAttribute('aria-pressed', 'true'));

		await userEvent.click(tab('library.tab.owned'));
		await waitFor(() => expect(tab('library.tab.owned')).toHaveAttribute('aria-pressed', 'true'));
		expect(tab('library.tab.wishlist')).toHaveAttribute('aria-pressed', 'false');
		expect(goto).toHaveBeenLastCalledWith('/library?tab=owned', {
			replaceState: true,
			keepFocus: true,
			noScroll: true
		});
		expect(get(page).url.searchParams.get('tab')).toBe('owned');
		expect(get(libraryStore).activeTab).toBe('owned');
	});

	it('maps ?filter=collection and drops it when the user picks "all"', async () => {
		setUrl('/library?filter=collection');
		render_();
		await waitFor(() => expect(tab('library.tab.owned')).toHaveAttribute('aria-pressed', 'true'));

		await userEvent.click(tab('library.tab.all'));
		await waitFor(() => expect(tab('library.tab.all')).toHaveAttribute('aria-pressed', 'true'));
		expect(goto).toHaveBeenLastCalledWith('/library', expect.objectContaining({ replaceState: true }));
		expect(get(libraryStore).activeTab).toBe('all');
	});

	it('follows a later URL change (e.g. another deep link while on the page)', async () => {
		render_();
		await userEvent.click(tab('library.tab.owned'));
		setUrl('/library?tab=favorites');
		await waitFor(() => expect(tab('library.tab.favorites')).toHaveAttribute('aria-pressed', 'true'));
	});
});
