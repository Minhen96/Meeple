import { describe, expect, it, vi } from 'vitest';
import type { BggImportStatus } from '$lib/types';
import { createBggImportPoller, progressPercent, type BggImportApi, type BggImportView } from './bggImport';

function status(overrides: Partial<BggImportStatus>): BggImportStatus {
	return {
		status: 'running',
		total: 0,
		processed: 0,
		imported: 0,
		skipped: 0,
		failed: 0,
		errorCode: null,
		preview: [],
		...overrides
	};
}

/** Manual timers: `flush()` runs the pending poll. */
function manualTimers() {
	let pending: (() => void) | null = null;
	const delays: number[] = [];
	return {
		timers: {
			setTimeout: (fn: () => void, ms: number) => {
				pending = fn;
				delays.push(ms);
				return 1;
			},
			clearTimeout: () => {
				pending = null;
			}
		},
		delays,
		hasPending: () => pending !== null,
		async flush() {
			const fn = pending;
			pending = null;
			fn?.();
			await new Promise((resolve) => setTimeout(resolve, 0));
		}
	};
}

function setup(api: BggImportApi) {
	const views: BggImportView[] = [];
	const t = manualTimers();
	const poller = createBggImportPoller(api, (v) => views.push(v), { timers: t.timers });
	return { views, t, poller };
}

class FakeApiError extends Error {
	constructor(
		public readonly code: string,
		public readonly status: number
	) {
		super(code);
	}
}

describe('createBggImportPoller', () => {
	it('starts, polls every 2s while running, and stops when done', async () => {
		const statuses = [
			status({ total: 4, processed: 2 }),
			status({ status: 'done', total: 4, processed: 4, imported: 3, skipped: 1 })
		];
		const api: BggImportApi = {
			startBggImport: vi.fn().mockResolvedValue(status({})),
			getBggImportStatus: vi.fn(async () => statuses.shift()!)
		};
		const { views, t, poller } = setup(api);

		await poller.start('  alice  ');
		expect(api.startBggImport).toHaveBeenCalledWith('alice');
		expect(views[0]).toEqual({ phase: 'running', status: null });
		expect(t.delays).toEqual([2000]);

		await t.flush();
		expect(views.at(-1)).toMatchObject({ phase: 'running', status: { processed: 2 } });
		await t.flush();
		expect(views.at(-1)).toMatchObject({ phase: 'done', status: { imported: 3 } });
		expect(t.hasPending()).toBe(false);
		expect(api.getBggImportStatus).toHaveBeenCalledTimes(2);
	});

	it('reports the backend error code when the start is rejected', async () => {
		const api: BggImportApi = {
			startBggImport: vi.fn().mockRejectedValue(new FakeApiError('BGG_API_UNAVAILABLE', 503)),
			getBggImportStatus: vi.fn()
		};
		const { views, t, poller } = setup(api);

		await poller.start('alice');
		expect(views.at(-1)).toEqual({ phase: 'failed', errorCode: 'BGG_API_UNAVAILABLE' });
		expect(t.hasPending()).toBe(false);
		expect(api.getBggImportStatus).not.toHaveBeenCalled();
	});

	it('maps a failed status and an unknown error', async () => {
		const api: BggImportApi = {
			startBggImport: vi.fn().mockRejectedValue(new Error('network')),
			getBggImportStatus: vi.fn().mockResolvedValue(status({ status: 'failed', errorCode: 'BGG_USER_NOT_FOUND' }))
		};
		const { views, poller } = setup(api);

		await poller.start('alice');
		expect(views.at(-1)).toEqual({ phase: 'failed', errorCode: 'BGG_API_UNAVAILABLE' });

		await poller.resume();
		expect(views.at(-1)).toEqual({ phase: 'failed', errorCode: 'BGG_USER_NOT_FOUND' });
	});

	it('keeps polling through transient errors but stops on an expired session', async () => {
		const api: BggImportApi = {
			startBggImport: vi.fn().mockResolvedValue(status({})),
			getBggImportStatus: vi
				.fn()
				.mockRejectedValueOnce(new Error('offline'))
				.mockRejectedValueOnce(new FakeApiError('SESSION_EXPIRED', 401))
		};
		const { views, t, poller } = setup(api);

		await poller.start('alice');
		await t.flush(); // offline: rescheduled
		expect(t.hasPending()).toBe(true);
		await t.flush(); // 401: stop
		expect(views.at(-1)).toEqual({ phase: 'failed', errorCode: 'SESSION_EXPIRED' });
		expect(t.hasPending()).toBe(false);
	});

	it('ignores a blank username, and stop() cancels polling and late answers', async () => {
		let resolveStatus: (s: BggImportStatus) => void = () => {};
		const api: BggImportApi = {
			startBggImport: vi.fn().mockResolvedValue(status({})),
			getBggImportStatus: vi.fn(() => new Promise<BggImportStatus>((r) => (resolveStatus = r)))
		};
		const { views, t, poller } = setup(api);

		await poller.start('   ');
		expect(api.startBggImport).not.toHaveBeenCalled();
		expect(views).toEqual([]);

		await poller.start('alice');
		void t.flush();
		poller.stop();
		resolveStatus(status({ status: 'done' }));
		await new Promise((resolve) => setTimeout(resolve, 0));
		expect(views.at(-1)).toEqual({ phase: 'running', status: null });
	});

	it('resume() reports idle when nothing is running', async () => {
		const api: BggImportApi = {
			startBggImport: vi.fn(),
			getBggImportStatus: vi.fn().mockResolvedValue(status({ status: 'idle' }))
		};
		const { views, poller } = setup(api);
		await poller.resume();
		expect(views).toEqual([{ phase: 'idle' }]);
	});

	it('uses real timers by default', async () => {
		vi.useFakeTimers();
		try {
			const api: BggImportApi = {
				startBggImport: vi.fn().mockResolvedValue(status({})),
				getBggImportStatus: vi.fn().mockResolvedValue(status({ status: 'done' }))
			};
			const views: BggImportView[] = [];
			const poller = createBggImportPoller(api, (v) => views.push(v));
			await poller.start('alice');
			await vi.advanceTimersByTimeAsync(2000);
			expect(views.at(-1)).toMatchObject({ phase: 'done' });
		} finally {
			vi.useRealTimers();
		}
	});
});

describe('progressPercent', () => {
	it('is 0 until the total is known, then processed/total capped at 100', () => {
		expect(progressPercent(null)).toBe(0);
		expect(progressPercent(status({ total: 0 }))).toBe(0);
		expect(progressPercent(status({ total: 45, processed: 12 }))).toBe(27);
		expect(progressPercent(status({ total: 4, processed: 9 }))).toBe(100);
	});
});
