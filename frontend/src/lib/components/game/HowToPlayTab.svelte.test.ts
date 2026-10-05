// HowToPlayTab state machine: loading → generating (WS + polling) → ready / failed / error.
// Copy in this component is being localised, so assertions use roles, API calls and the
// content we feed in rather than the component's own English strings.
import { act, render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiRequestError } from '$lib/api/client';
import { errorMessage } from '$lib/i18n';
import { setUser } from '$lib/stores/auth';
import type { HowToPlayApiResponse, RulebookStatus, User } from '$lib/types';
import type { HowToPlayProgressMessage } from '$lib/stores/websocket';
import HowToPlayTab from './HowToPlayTab.svelte';

const h = vi.hoisted(() => ({
	toast: { success: vi.fn(), error: vi.fn() },
	rulebook: { getStatus: vi.fn(), upload: vi.fn() },
	admin: { uploadRulebookForGame: vi.fn() },
	htp: { get: vi.fn(), generate: vi.fn() },
	notes: { getMy: vi.fn(), submit: vi.fn(), deleteMy: vi.fn() },
	ws: {
		listener: null as null | ((m: HowToPlayProgressMessage) => void),
		unsubscribe: vi.fn(),
		subscribe: vi.fn()
	}
}));
vi.mock('svelte-sonner', () => ({ toast: h.toast }));
vi.mock('$lib/session', () => ({ clearClientSession: vi.fn() }));
vi.mock('$lib/api/rulebook', () => ({ rulebookApi: h.rulebook }));
vi.mock('$lib/api/admin', () => ({ adminApi: h.admin }));
vi.mock('$lib/api/howtoplay', () => ({ howToPlayApi: h.htp }));
vi.mock('$lib/api/ruleNotes', () => ({ ruleNotesApi: h.notes }));
vi.mock('$lib/stores/websocket', () => ({ subscribeToHowToPlayProgress: h.ws.subscribe }));

const status = (s: Partial<RulebookStatus> = {}): RulebookStatus => ({
	hasRulebook: true,
	isIngesting: false,
	myStatus: null,
	myQueuePosition: null,
	hasHowToPlay: false,
	...s
});

const htp = (s: Partial<HowToPlayApiResponse> = {}): HowToPlayApiResponse => ({
	status: 'not_generated',
	data: null,
	sourceMode: null,
	disclaimer: null,
	rulebookUrl: null,
	approvedNotes: [],
	progress: null,
	errorMessage: null,
	...s
});

const READY = htp({
	status: 'ready',
	sourceMode: 'rulebook',
	rulebookUrl: 'https://cdn/rules.pdf',
	data: {
		overview: 'OVERVIEW_TEXT',
		objective: 'OBJECTIVE_TEXT',
		setup: 'SETUP_TEXT',
		faq: [{ question: 'FAQ_Q1', answer: 'FAQ_A1' }]
	} as HowToPlayApiResponse['data'],
	approvedNotes: [{ id: 'n1', content: 'COMMUNITY_NOTE', submittedByUsername: 'bob', createdAt: '2026-01-01T00:00:00Z' }]
});

const progressbar = () => screen.getByRole('progressbar') as HTMLProgressElement;

beforeEach(() => {
	for (const group of [h.toast, h.rulebook, h.admin, h.htp, h.notes]) for (const fn of Object.values(group)) fn.mockReset();
	h.ws.listener = null;
	h.ws.unsubscribe.mockReset();
	h.ws.subscribe.mockReset().mockImplementation((_gameId: string, cb: (m: HowToPlayProgressMessage) => void) => {
		h.ws.listener = cb;
		return h.ws.unsubscribe;
	});
	h.notes.getMy.mockResolvedValue(null);
	setUser(null);
});

afterEach(() => {
	vi.useRealTimers();
});

describe('HowToPlayTab', () => {
	it('shows a skeleton while the rulebook status loads', () => {
		h.rulebook.getStatus.mockReturnValue(new Promise(() => {}));
		const { container } = render(HowToPlayTab, { gameId: 'g1' });
		expect(h.rulebook.getStatus).toHaveBeenCalledWith('g1');
		expect(container.querySelector('.animate-pulse')).not.toBeNull();
		expect(screen.queryByRole('progressbar')).toBeNull();
		expect(screen.queryByRole('alert')).toBeNull();
	});

	it('renders a ready guide with community notes, rulebook link and expandable FAQ', async () => {
		h.rulebook.getStatus.mockResolvedValue(status());
		h.htp.get.mockResolvedValue(READY);
		render(HowToPlayTab, { gameId: 'g1' });
		expect(await screen.findByText('OVERVIEW_TEXT')).toBeInTheDocument();
		expect(screen.getByText('SETUP_TEXT')).toBeInTheDocument();
		expect(screen.getByText('COMMUNITY_NOTE')).toBeInTheDocument();
		expect(document.querySelector('a[href="https://cdn/rules.pdf"]')).not.toBeNull();
		expect(h.notes.getMy).toHaveBeenCalledWith('g1');

		expect(screen.queryByText('FAQ_A1')).toBeNull();
		await userEvent.click(screen.getByRole('button', { name: /FAQ_Q1/ }));
		expect(screen.getByText('FAQ_A1')).toBeInTheDocument();
		await userEvent.click(screen.getByRole('button', { name: /FAQ_Q1/ }));
		expect(screen.queryByText('FAQ_A1')).toBeNull();
	});

	it('pending review: waits for an admin and does not load a guide', async () => {
		h.rulebook.getStatus.mockResolvedValue(status({ hasRulebook: false, myStatus: 'pending_review', myQueuePosition: 3 }));
		render(HowToPlayTab, { gameId: 'g1' });
		// Queue position is shown 1-based.
		await waitFor(() => expect(screen.getByText(/#4/)).toBeInTheDocument());
		expect(h.htp.get).not.toHaveBeenCalled();
	});

	it('rulebook status failure is reported', async () => {
		h.rulebook.getStatus.mockRejectedValue(new Error('net'));
		const { container } = render(HowToPlayTab, { gameId: 'g1' });
		await waitFor(() => expect(container.querySelector('.text-error')).not.toBeNull());
		expect(h.htp.get).not.toHaveBeenCalled();
	});

	describe('generation', () => {
		it('a guide already generating shows progress, advances on WS frames and loads when ready', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValueOnce(htp({ status: 'generating', progress: 20 }));
			render(HowToPlayTab, { gameId: 'g1' });
			await waitFor(() => expect(progressbar().value).toBe(20));
			expect(h.ws.subscribe).toHaveBeenCalledWith('g1', expect.any(Function));

			await act(() => h.ws.listener?.({ status: 'generating', progress: 60 }));
			expect(progressbar().value).toBe(60);
			// Progress never goes backwards.
			await act(() => h.ws.listener?.({ status: 'generating', progress: 40 }));
			expect(progressbar().value).toBe(60);

			h.htp.get.mockResolvedValueOnce(READY);
			await act(() => h.ws.listener?.({ status: 'ready', progress: 100 }));
			expect(await screen.findByText('OVERVIEW_TEXT')).toBeInTheDocument();
			expect(h.ws.unsubscribe).toHaveBeenCalled();
		});

		it('a WS failure frame shows the failed state with its message; Retry regenerates', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValueOnce(htp({ status: 'generating', progress: 0 }));
			render(HowToPlayTab, { gameId: 'g1' });
			await waitFor(() => expect(h.ws.listener).not.toBeNull());
			await act(() => h.ws.listener?.({ status: 'failed', progress: 0, errorMessage: 'RULEBOOK_UNREADABLE' }));
			const alert = await screen.findByRole('alert');
			expect(alert).toHaveTextContent('RULEBOOK_UNREADABLE');
			expect(h.ws.unsubscribe).toHaveBeenCalled();

			h.htp.generate.mockReturnValue(new Promise(() => {}));
			await userEvent.click(within(alert).getByRole('button'));
			expect(h.htp.generate).toHaveBeenCalledWith('g1');
			expect(progressbar().value).toBe(0);
		});

		it('legacy "error" frames and a failed GET also land in the failed state', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValueOnce(htp({ status: 'generating', progress: 0 }));
			render(HowToPlayTab, { gameId: 'g1' });
			await waitFor(() => expect(h.ws.listener).not.toBeNull());
			await act(() => h.ws.listener?.({ status: 'error', progress: 0 }));
			expect(await screen.findByRole('alert')).toBeInTheDocument();
		});

		it('a failed guide from GET offers a retry', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValue(htp({ status: 'failed', errorMessage: 'NO_TEXT_LAYER' }));
			render(HowToPlayTab, { gameId: 'g1' });
			expect(await screen.findByRole('alert')).toHaveTextContent('NO_TEXT_LAYER');
		});

		it('Generate subscribes before POSTing and applies an immediate ready response', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValue(htp());
			const order: string[] = [];
			h.ws.subscribe.mockImplementation((_g: string, cb: (m: HowToPlayProgressMessage) => void) => {
				order.push('subscribe');
				h.ws.listener = cb;
				return h.ws.unsubscribe;
			});
			h.htp.generate.mockImplementation(async () => {
				order.push('generate');
				return READY;
			});
			render(HowToPlayTab, { gameId: 'g1' });
			const generate = await screen.findByRole('button');
			await userEvent.click(generate);
			expect(await screen.findByText('OVERVIEW_TEXT')).toBeInTheDocument();
			expect(order).toEqual(['subscribe', 'generate']);
		});

		it('Generate with a failed response shows the failure', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValue(htp());
			h.htp.generate.mockResolvedValue(htp({ status: 'failed', errorMessage: 'QUOTA' }));
			render(HowToPlayTab, { gameId: 'g1' });
			await userEvent.click(await screen.findByRole('button'));
			expect(await screen.findByRole('alert')).toHaveTextContent('QUOTA');
		});

		it('a rate-limited Generate returns to idle with a toast; other errors show the error state', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValue(htp());
			h.htp.generate.mockRejectedValueOnce(new ApiRequestError('RATE_LIMITED', 'slow', 429, 30));
			render(HowToPlayTab, { gameId: 'g1' });
			await userEvent.click(await screen.findByRole('button'));
			await waitFor(() => expect(h.toast.error).toHaveBeenCalledWith(errorMessage('RATE_LIMITED')));
			expect(screen.queryByRole('alert')).toBeNull();
			expect(screen.getByRole('button')).toBeInTheDocument();

			h.htp.generate.mockRejectedValueOnce(new ApiRequestError('REFRESH_UNAVAILABLE', 'Could not reach the server', 0));
			await userEvent.click(screen.getByRole('button'));
			expect(await screen.findByRole('alert')).toBeInTheDocument();
			expect(h.toast.error).toHaveBeenLastCalledWith(errorMessage('REFRESH_UNAVAILABLE'));
		});

		it('polls as a fallback when WS frames are missed', async () => {
			vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValueOnce(htp({ status: 'generating', progress: 10 }));
			render(HowToPlayTab, { gameId: 'g1' });
			await waitFor(() => expect(progressbar().value).toBe(10));

			h.htp.get.mockResolvedValueOnce(htp({ status: 'generating', progress: 50 }));
			await act(() => vi.advanceTimersByTimeAsync(5000));
			await waitFor(() => expect(progressbar().value).toBe(50));

			h.htp.get.mockRejectedValueOnce(new Error('blip'));
			await act(() => vi.advanceTimersByTimeAsync(5000));
			expect(screen.getByRole('progressbar')).toBeInTheDocument();

			h.htp.get.mockResolvedValueOnce(READY);
			await act(() => vi.advanceTimersByTimeAsync(5000));
			expect(await screen.findByText('OVERVIEW_TEXT')).toBeInTheDocument();
		});

		it('stops tracking on unmount', async () => {
			h.rulebook.getStatus.mockResolvedValue(status());
			h.htp.get.mockResolvedValueOnce(htp({ status: 'generating', progress: 0 }));
			const { unmount } = render(HowToPlayTab, { gameId: 'g1' });
			await waitFor(() => expect(h.ws.subscribe).toHaveBeenCalled());
			unmount();
			expect(h.ws.unsubscribe).toHaveBeenCalled();
		});
	});

	it('a guide load error shows a retry that reloads the guide', async () => {
		h.rulebook.getStatus.mockResolvedValue(status());
		h.htp.get.mockRejectedValueOnce(new Error('net')).mockResolvedValueOnce(READY);
		render(HowToPlayTab, { gameId: 'g1' });
		const alert = await screen.findByRole('alert');
		await userEvent.click(within(alert).getByRole('button'));
		expect(await screen.findByText('OVERVIEW_TEXT')).toBeInTheDocument();
		expect(h.htp.get).toHaveBeenCalledTimes(2);
	});

	it('a signed-in user can submit a rule note for review', async () => {
		setUser({ id: 'u1', username: 'u1' } as User);
		h.rulebook.getStatus.mockResolvedValue(status());
		h.htp.get.mockResolvedValue(READY);
		h.notes.submit.mockResolvedValue({ id: 'm1', content: 'MY_NOTE', status: 'pending', rejectReason: null, createdAt: '' });
		render(HowToPlayTab, { gameId: 'g1' });
		await screen.findByText('OVERVIEW_TEXT');
		const before = screen.getAllByRole('button').length;
		// The "add note" button is the last control in the notes section.
		await userEvent.click(screen.getAllByRole('button').at(-1) as HTMLElement);
		const box = await screen.findByRole('textbox');
		await userEvent.type(box, '  MY_NOTE  ');
		const buttons = screen.getAllByRole('button');
		expect(buttons.length).toBeGreaterThan(before);
		await userEvent.click(buttons.at(-1) as HTMLElement);
		expect(h.notes.submit).toHaveBeenCalledWith('g1', 'MY_NOTE');
		expect(await screen.findByText('MY_NOTE')).toBeInTheDocument();
		expect(h.toast.success).toHaveBeenCalled();
	});
});
