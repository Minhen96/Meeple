import { createRawSnippet } from 'svelte';
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { act } from '@testing-library/svelte';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { m } from '$lib/i18n';
import Button from './Button.svelte';
import ConfirmDialog from './ConfirmDialog.svelte';
import OfflineBanner from '../layout/OfflineBanner.svelte';

const text = (s: string) => createRawSnippet(() => ({ render: () => `<span>${s}</span>` }));

describe('Button', () => {
	it('renders children and calls onclick', async () => {
		const onclick = vi.fn();
		render(Button, { onclick, children: text('Save') });
		await userEvent.click(screen.getByRole('button', { name: 'Save' }));
		expect(onclick).toHaveBeenCalledTimes(1);
	});

	it('defaults to type=button and is not busy', () => {
		render(Button, { children: text('Go') });
		const btn = screen.getByRole('button');
		expect(btn).toHaveAttribute('type', 'button');
		expect(btn).toHaveAttribute('aria-busy', 'false');
	});

	it('disabled buttons do not fire', async () => {
		const onclick = vi.fn();
		render(Button, { onclick, disabled: true, children: text('Nope') });
		const btn = screen.getByRole('button');
		expect(btn).toBeDisabled();
		await userEvent.click(btn);
		expect(onclick).not.toHaveBeenCalled();
	});

	it('loading marks the button busy, and submit/fullWidth/variant are applied', () => {
		render(Button, { loading: true, type: 'submit', fullWidth: true, variant: 'danger', children: text('Delete') });
		const btn = screen.getByRole('button');
		expect(btn).toHaveAttribute('aria-busy', 'true');
		expect(btn).toHaveAttribute('type', 'submit');
		expect(btn.className).toContain('w-full');
		expect(btn.className).toContain('bg-error');
	});
});

describe('ConfirmDialog', () => {
	const base = () => ({ title: 'Delete post?', message: 'This cannot be undone.', onConfirm: vi.fn(), onCancel: vi.fn() });

	it('is an accessible dialog with title and message', () => {
		render(ConfirmDialog, base());
		const dialog = screen.getByRole('dialog', { name: 'Delete post?' });
		expect(dialog).toHaveTextContent('This cannot be undone.');
	});

	it('confirm and cancel call their handlers (default labels from i18n)', async () => {
		const props = base();
		render(ConfirmDialog, props);
		await userEvent.click(screen.getByRole('button', { name: m('common.confirm') }));
		expect(props.onConfirm).toHaveBeenCalledTimes(1);
		await userEvent.click(screen.getByRole('button', { name: m('common.cancel') }));
		expect(props.onCancel).toHaveBeenCalledTimes(1);
	});

	it('Escape and the backdrop cancel', async () => {
		const props = base();
		render(ConfirmDialog, props);
		await userEvent.keyboard('{Escape}');
		expect(props.onCancel).toHaveBeenCalledTimes(1);
		await userEvent.click(screen.getByRole('button', { name: m('common.close') }));
		expect(props.onCancel).toHaveBeenCalledTimes(2);
	});

	it('uses custom labels and the danger style', () => {
		render(ConfirmDialog, { ...base(), danger: true, confirmLabel: 'Delete', cancelLabel: 'Keep' });
		expect(screen.getByRole('button', { name: 'Delete' }).className).toContain('bg-error');
		expect(screen.getByRole('button', { name: 'Keep' })).toBeInTheDocument();
	});

	it('shows the busy state while loading', () => {
		render(ConfirmDialog, { ...base(), loading: true, confirmLabel: 'Delete' });
		expect(screen.getByRole('button', { name: /Delete/ })).toHaveAttribute('aria-busy', 'true');
	});
});

describe('OfflineBanner', () => {
	let online = true;
	beforeEach(() => {
		online = true;
		vi.spyOn(navigator, 'onLine', 'get').mockImplementation(() => online);
	});
	afterEach(() => {
		vi.restoreAllMocks();
		vi.useRealTimers();
	});

	it('renders nothing while online', () => {
		render(OfflineBanner);
		expect(screen.queryByRole('status')).toBeNull();
	});

	it('shows the offline status, then flashes back-online and hides', async () => {
		vi.useFakeTimers();
		online = false;
		render(OfflineBanner);
		expect(screen.getByRole('status')).toHaveTextContent(m('common.noInternet'));

		await act(() => window.dispatchEvent(new Event('online')));
		expect(screen.getByRole('status')).toHaveTextContent(m('common.backOnline'));

		await act(() => vi.advanceTimersByTime(3000));
		await vi.runAllTimersAsync();
		expect(screen.queryByText(m('common.backOnline'))).toBeNull();
	});

	it('going offline while online shows the banner', async () => {
		render(OfflineBanner);
		await act(() => window.dispatchEvent(new Event('offline')));
		expect(screen.getByRole('status')).toHaveTextContent(m('common.noInternet'));
	});
});
