import type { CursorPage } from '$lib/types';

/** Infinite-scroll trigger depth (SCREENS_AND_STATES 4.6: fetch the next page at 80%). */
export const LOAD_MORE_DEPTH = 0.8;

/**
 * True once the viewport's bottom edge has passed `depth` of the scrollable height. Content that
 * does not fill the viewport counts as fully scrolled, so short first pages keep loading.
 */
export function reachedScrollDepth(
	scrollTop: number,
	viewportHeight: number,
	scrollHeight: number,
	depth = LOAD_MORE_DEPTH
): boolean {
	if (scrollHeight <= viewportHeight) return true;
	return (scrollTop + viewportHeight) / scrollHeight >= depth;
}

/**
 * Calls `onReach` whenever the window is scrolled (or resized) past `depth` of the page height.
 * Returns the cleanup function. Browser only; call from onMount / $effect.
 */
export function watchScrollDepth(onReach: () => void, depth = LOAD_MORE_DEPTH): () => void {
	const check = () => {
		if (
			reachedScrollDepth(
				window.scrollY,
				window.innerHeight,
				document.documentElement.scrollHeight,
				depth
			)
		) {
			onReach();
		}
	};
	window.addEventListener('scroll', check, { passive: true });
	window.addEventListener('resize', check);
	check();
	return () => {
		window.removeEventListener('scroll', check);
		window.removeEventListener('resize', check);
	};
}

/**
 * Rebuilds `next` reusing the matching items of `prev` (by key), so local edits a component made
 * to loaded items (an optimistic like) survive when the pager appends a page.
 */
export function preferExisting<T>(prev: T[], next: T[], key: (item: T) => string): T[] {
	if (prev.length === 0) return next;
	const local = new Map(prev.map((item) => [key(item), item]));
	return next.map((item) => local.get(key(item)) ?? item);
}

export type FetchPage<T> = (cursor: string | null) => Promise<CursorPage<T>>;

export interface PagerState<T> {
	items: T[];
	/** First page is loading (show skeletons). */
	loading: boolean;
	/** A later page is loading ("Loading more…"). */
	loadingMore: boolean;
	hasMore: boolean;
	/** The last request failed; `loadMore()` / `refresh()` retries. */
	error: unknown;
	/** At least one page has loaded successfully. */
	loaded: boolean;
}

/**
 * Cursor pagination state machine shared by the feed, bookmarks and memories lists. Requests never
 * overlap; a `refresh()` while a page is in flight discards that page's result; items are
 * de-duplicated by `key` in case a page boundary moved.
 */
export class CursorPager<T> {
	private state: PagerState<T>;
	private cursor: string | null = null;
	private generation = 0;
	private inFlight: Promise<void> | null = null;

	constructor(
		private readonly fetchPage: FetchPage<T>,
		private readonly key: (item: T) => string,
		private readonly onChange: (state: PagerState<T>) => void = () => {},
		initial?: CursorPage<T>
	) {
		this.state = {
			items: [],
			loading: false,
			loadingMore: false,
			hasMore: true,
			error: null,
			loaded: false
		};
		if (initial) this.accept(initial, true);
	}

	get snapshot(): PagerState<T> {
		return this.state;
	}

	/** Loads the next page unless one is loading or the end was reached. */
	loadMore(): Promise<void> {
		if (this.inFlight) return this.inFlight;
		if (this.state.loaded && !this.state.hasMore) return Promise.resolve();
		return this.run(this.state.loaded ? this.cursor : null, !this.state.loaded);
	}

	/** Reloads from the first page (pull-to-refresh, retry after an error on the first page). */
	refresh(): Promise<void> {
		this.generation++;
		this.inFlight = null;
		this.cursor = null;
		this.set({
			...this.state,
			items: [],
			error: null,
			hasMore: true,
			loaded: false
		});
		return this.run(null, true);
	}

	/** Applies a local change (optimistic like, delete) to the loaded items. */
	update(fn: (items: T[]) => T[]): void {
		this.set({ ...this.state, items: fn(this.state.items) });
	}

	private run(cursor: string | null, first: boolean): Promise<void> {
		const generation = this.generation;
		this.set({
			...this.state,
			loading: first,
			loadingMore: !first,
			error: null
		});
		const request = this.fetchPage(cursor)
			.then((page) => {
				if (generation === this.generation) this.accept(page, first);
			})
			.catch((error: unknown) => {
				if (generation === this.generation) {
					this.set({
						...this.state,
						loading: false,
						loadingMore: false,
						error
					});
				}
			})
			.finally(() => {
				if (generation === this.generation) this.inFlight = null;
			});
		this.inFlight = request;
		return request;
	}

	private accept(page: CursorPage<T>, first: boolean): void {
		const base = first ? [] : this.state.items;
		const seen = new Set(base.map(this.key));
		const fresh = page.items.filter((item) => {
			const k = this.key(item);
			if (seen.has(k)) return false;
			seen.add(k);
			return true;
		});
		this.cursor = page.nextCursor;
		this.set({
			items: [...base, ...fresh],
			loading: false,
			loadingMore: false,
			hasMore: page.hasMore && page.nextCursor !== null,
			error: null,
			loaded: true
		});
	}

	private set(state: PagerState<T>): void {
		this.state = state;
		this.onChange(state);
	}
}
