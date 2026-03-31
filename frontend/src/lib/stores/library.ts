import { writable } from 'svelte/store';

interface GamesPage {
	content: any[];
	number: number;
	last: boolean;
	totalPages: number;
	totalElements: number;
}

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

const defaultState: LibraryState = {
	gamesPage: { content: [], number: 0, last: true, totalPages: 1, totalElements: 0 },
	activeTab: 'all',
	sortOption: '',
	selectedGenre: ''
};

export const libraryStore = writable<LibraryState>(defaultState);
