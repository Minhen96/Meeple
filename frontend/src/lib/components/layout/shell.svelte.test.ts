// Responsive app shell: sidebar / rail navigation, create menu, layout containers, sheets.
import { createRawSnippet } from 'svelte';
import { render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { goto } from '$app/navigation';
import { page } from '../../../test/stubs/app-state';
import { m } from '$lib/i18n';
import { currentUser } from '$lib/stores/auth';
import { resetNotifications, setUnreadCount } from '$lib/stores/notifications';
import type { User } from '$lib/types';
import BottomSheet from '../ui/BottomSheet.svelte';
import EventSheet from '../event/BottomSheet.svelte';
import BottomNav from './BottomNav.svelte';
import CreateMenu from './CreateMenu.svelte';
import PageContainer from './PageContainer.svelte';
import Sidebar from './Sidebar.svelte';
import TwoColumn from './TwoColumn.svelte';

const h = vi.hoisted(() => ({ logout: vi.fn(async () => {}) }));
vi.mock('$lib/session', () => ({ logout: h.logout, clearClientSession: vi.fn() }));

const text = (s: string) => createRawSnippet(() => ({ render: () => `<span>${s}</span>` }));
const alice = { id: 'u1', username: 'alice', displayName: 'Alice Tan', avatarUrl: null } as unknown as User;

beforeEach(() => {
	resetNotifications();
	currentUser.set(alice);
	page.url = new URL('http://localhost/library/abc');
	h.logout.mockClear();
	vi.mocked(goto).mockClear();
});

afterEach(() => {
	currentUser.set(null);
	page.url = new URL('http://localhost/');
});

describe('Sidebar', () => {
	it('is a navigation landmark with every destination and marks the current section', () => {
		render(Sidebar);
		const nav = screen.getByRole('navigation', { name: m('common.nav.label') });
		const links = within(nav).getAllByRole('link');
		expect(links.map((a) => a.getAttribute('href'))).toEqual([
			'/',
			'/library',
			'/events',
			'/match',
			'/notifications',
			'/search',
			'/profile'
		]);
		expect(within(nav).getByRole('link', { name: m('common.nav.library') })).toHaveAttribute('aria-current', 'page');
		expect(within(nav).getByRole('link', { name: m('common.nav.home') })).not.toHaveAttribute('aria-current');
	});

	it('shows the unread badge and names it for screen readers', async () => {
		setUnreadCount(120);
		render(Sidebar);
		expect(await screen.findByTestId('sidebar-badge')).toHaveTextContent('99+');
		expect(screen.getByRole('link', { name: m('common.notificationsUnread', { count: 120 }) })).toHaveAttribute(
			'href',
			'/notifications'
		);
	});

	it('hides the badge with nothing unread', () => {
		setUnreadCount(0);
		render(Sidebar);
		expect(screen.queryByTestId('sidebar-badge')).toBeNull();
	});

	it('shows the signed-in user with settings and logout', async () => {
		page.url = new URL('http://localhost/settings/profile');
		render(Sidebar);
		const account = screen.getByRole('region', { name: m('common.nav.account') });
		expect(account).toHaveTextContent('Alice Tan');
		expect(account).toHaveTextContent('@alice');
		expect(within(account).getByRole('link', { name: m('common.nav.settings') })).toHaveAttribute('aria-current', 'page');
		await userEvent.click(within(account).getByRole('button', { name: m('common.nav.logout') }));
		expect(h.logout).toHaveBeenCalledTimes(1);
		await waitFor(() => expect(goto).toHaveBeenCalledWith('/auth/login'));
	});

	it('omits the account block when signed out', () => {
		currentUser.set(null);
		render(Sidebar);
		expect(screen.queryByRole('region', { name: m('common.nav.account') })).toBeNull();
	});
});

describe('CreateMenu', () => {
	it('opens the create options as a menu and focuses the first item', async () => {
		render(CreateMenu);
		const trigger = screen.getByRole('button', { name: m('common.create.title') });
		expect(trigger).toHaveAttribute('aria-expanded', 'false');
		await userEvent.click(trigger);
		const menu = screen.getByRole('menu');
		const items = within(menu).getAllByRole('menuitem');
		expect(items.map((a) => a.getAttribute('href'))).toEqual(['/posts/create', '/events/create', '/library', '/match']);
		expect(trigger).toHaveAttribute('aria-expanded', 'true');
		await waitFor(() => expect(items[0]).toHaveFocus());
	});

	it('moves with arrow keys, wraps, and closes on Escape back to the trigger', async () => {
		render(CreateMenu);
		const trigger = screen.getByRole('button', { name: m('common.create.title') });
		trigger.focus();
		await userEvent.keyboard('{ArrowDown}');
		const items = await screen.findAllByRole('menuitem');
		await waitFor(() => expect(items[0]).toHaveFocus());
		await userEvent.keyboard('{ArrowDown}');
		expect(items[1]).toHaveFocus();
		await userEvent.keyboard('{ArrowUp}{ArrowUp}');
		expect(items[3]).toHaveFocus();
		await userEvent.keyboard('{Home}');
		expect(items[0]).toHaveFocus();
		await userEvent.keyboard('{End}');
		expect(items[3]).toHaveFocus();
		await userEvent.keyboard('{Escape}');
		await waitFor(() => expect(screen.queryByRole('menu')).toBeNull());
		expect(trigger).toHaveFocus();
	});

	it('closes on an outside click, on Tab and after choosing an item', async () => {
		render(CreateMenu);
		const trigger = screen.getByRole('button', { name: m('common.create.title') });
		await userEvent.click(trigger);
		await userEvent.click(document.body);
		await waitFor(() => expect(screen.queryByRole('menu')).toBeNull());

		await userEvent.click(trigger);
		await screen.findByRole('menu');
		await userEvent.keyboard('{Tab}');
		await waitFor(() => expect(screen.queryByRole('menu')).toBeNull());

		await userEvent.click(trigger);
		const item = (await screen.findAllByRole('menuitem'))[1];
		item.addEventListener('click', (e) => e.preventDefault());
		await userEvent.click(item);
		await waitFor(() => expect(screen.queryByRole('menu')).toBeNull());

		// a second click on the trigger toggles it shut
		await userEvent.click(trigger);
		await screen.findByRole('menu');
		await userEvent.click(trigger);
		await waitFor(() => expect(screen.queryByRole('menu')).toBeNull());
	});
});

describe('BottomNav', () => {
	it('is mobile-only and marks the active tab', () => {
		page.url = new URL('http://localhost/events/e1');
		render(BottomNav);
		const nav = screen.getByRole('navigation');
		expect(nav.className).toContain('md:hidden');
		expect(within(nav).getByRole('link', { name: new RegExp(m('common.nav.events')) })).toHaveAttribute('aria-current', 'page');
	});
});

describe('PageContainer', () => {
	it('defaults to narrow and marks itself for the shell', () => {
		render(PageContainer, { children: text('Feed') });
		const el = screen.getByText('Feed').parentElement as HTMLElement;
		expect(el).toHaveAttribute('data-page-container', 'narrow');
		expect(el.className).toContain('lg:max-w-2xl');
	});

	it('applies the wide and full variants and extra classes', () => {
		render(PageContainer, { width: 'wide', class: 'space-y-6', children: text('Grid') });
		const wide = screen.getByText('Grid').parentElement as HTMLElement;
		expect(wide).toHaveAttribute('data-page-container', 'wide');
		expect(wide.className).toContain('lg:max-w-6xl');
		expect(wide.className).toContain('space-y-6');
		render(PageContainer, { width: 'full', children: text('Map') });
		expect((screen.getByText('Map').parentElement as HTMLElement).className).toContain('max-w-none');
	});
});

describe('TwoColumn', () => {
	it('renders the rail as a labelled aside hidden below xl', () => {
		render(TwoColumn, { children: text('Main'), aside: text('Rail'), asideLabel: 'Suggestions' });
		const aside = screen.getByRole('complementary', { name: 'Suggestions' });
		expect(aside).toHaveTextContent('Rail');
		expect(aside.className).toContain('hidden');
		expect(aside.className).toContain('xl:block');
	});

	it('stacks the rail under the main column when asked', () => {
		render(TwoColumn, { children: text('Main'), aside: text('Rail'), asideLabel: 'More', stackAside: true });
		const aside = screen.getByRole('complementary', { name: 'More' });
		expect(aside).toHaveAttribute('data-stacked', 'true');
		expect(aside.className).not.toMatch(/(^|\s)hidden(\s|$)/);
	});

	it('renders only the main column without a rail', () => {
		render(TwoColumn, { children: text('Solo') });
		expect(screen.getByText('Solo')).toBeInTheDocument();
		expect(screen.queryByRole('complementary')).toBeNull();
	});
});

describe('sheets on wider screens', () => {
	function stubWidth(desktop: boolean) {
		vi.stubGlobal(
			'matchMedia',
			vi.fn((query: string) => ({
				matches: desktop && query.includes('min-width'),
				media: query,
				addEventListener: vi.fn(),
				removeEventListener: vi.fn()
			}))
		);
	}

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('BottomSheet is a bottom sheet on phones and a centred dialog from md', () => {
		stubWidth(true);
		render(BottomSheet, { title: 'Options', onClose: vi.fn(), children: text('Body') });
		const dialog = screen.getByRole('dialog', { name: 'Options' });
		expect(dialog.className).toContain('rounded-t-[2rem]');
		expect(dialog.className).toContain('md:rounded-[2rem]');
		expect(dialog.parentElement?.className).toContain('items-end');
		expect(dialog.parentElement?.className).toContain('md:items-center');
		// the drag handle is a phone affordance only
		expect(dialog.firstElementChild?.className).toContain('md:hidden');
	});

	it('the event sheet follows the same responsive pattern and closes on Escape', async () => {
		stubWidth(false);
		const onClose = vi.fn();
		render(EventSheet, { title: 'Day', onClose, children: text('Events') });
		const dialog = screen.getByRole('dialog', { name: 'Day' });
		expect(dialog.className).toContain('md:rounded-lg');
		expect(dialog.parentElement?.className).toContain('md:items-center');
		await userEvent.keyboard('{Escape}');
		expect(onClose).toHaveBeenCalled();
	});
});
