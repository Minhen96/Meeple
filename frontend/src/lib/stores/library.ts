import { writable } from 'svelte/store';
import type { GamesPage } from '$lib/api/games';

interface LibraryState {
	gamesPage: GamesPage;
	activeTab: 'all' | 'owned' | 'played' | 'favorites';
	minPlayers?: number;
	maxPlayers?: number;
	minPlaytime?: number;
	maxPlaytime?: number;
	minComplexity?: number;
	maxComplexity?: number;
	minRating?: number;
	sortOption: string;
	selectedGenre?: string;
}

export const defaultState: LibraryState = {
	gamesPage: { content: [], number: 0, last: true, totalPages: 1, totalElements: 0 },
	activeTab: 'all',
	sortOption: 'rank,asc',
	selectedGenre: ''
};

export const libraryStore = writable<LibraryState>(defaultState);
