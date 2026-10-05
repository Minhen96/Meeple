// BGG collection import client logic (SCREENS_AND_STATES section 3.4): start, then poll the
// status every 2s until done or failed. UI-free so it is unit-tested; BggImportPanel renders it.
import type { BggImportStatus } from '$lib/types';

export const POLL_INTERVAL_MS = 2000;

export interface BggImportApi {
	startBggImport(username: string): Promise<BggImportStatus>;
	getBggImportStatus(): Promise<BggImportStatus>;
}

/** What the panel shows. `errorCode` is a backend code when the import could not run. */
export type BggImportView =
	| { phase: 'idle' }
	| { phase: 'running'; status: BggImportStatus | null }
	| { phase: 'done'; status: BggImportStatus }
	| { phase: 'failed'; errorCode: string };

export interface BggImportPoller {
	start(username: string): Promise<void>;
	/** Resume polling an import that is already running (page reload). */
	resume(): Promise<void>;
	stop(): void;
}

interface Timers {
	setTimeout(fn: () => void, ms: number): unknown;
	clearTimeout(handle: unknown): void;
}

const defaultTimers: Timers = {
	setTimeout: (fn, ms) => globalThis.setTimeout(fn, ms),
	clearTimeout: (handle) => globalThis.clearTimeout(handle as ReturnType<typeof setTimeout>)
};

/** Percent done for the progress bar (0 while the total is unknown). */
export function progressPercent(status: BggImportStatus | null): number {
	if (!status || status.total <= 0) return 0;
	return Math.min(100, Math.round((status.processed / status.total) * 100));
}

function toView(status: BggImportStatus): BggImportView {
	switch (status.status) {
		case 'done':
			return { phase: 'done', status };
		case 'failed':
			return { phase: 'failed', errorCode: status.errorCode ?? 'BGG_API_UNAVAILABLE' };
		case 'running':
			return { phase: 'running', status };
		default:
			return { phase: 'idle' };
	}
}

/** `{code, status}` of an ApiRequestError (duck-typed so this module stays free of client.ts). */
function apiError(err: unknown): { code: string; status: number } | null {
	if (typeof err !== 'object' || err === null) return null;
	const { code, status } = err as { code?: unknown; status?: unknown };
	return typeof code === 'string' && typeof status === 'number' ? { code, status } : null;
}

function errorCodeOf(err: unknown): string {
	return apiError(err)?.code ?? 'BGG_API_UNAVAILABLE';
}

export function createBggImportPoller(
	api: BggImportApi,
	onChange: (view: BggImportView) => void,
	options: { intervalMs?: number; timers?: Timers } = {}
): BggImportPoller {
	const intervalMs = options.intervalMs ?? POLL_INTERVAL_MS;
	const timers = options.timers ?? defaultTimers;
	let handle: unknown = null;
	let active = false;

	const schedule = () => {
		handle = timers.setTimeout(() => void poll(), intervalMs);
	};

	async function poll(): Promise<void> {
		if (!active) return;
		try {
			const status = await api.getBggImportStatus();
			if (!active) return;
			const view = toView(status);
			onChange(view);
			if (view.phase === 'running') schedule();
			else active = false;
		} catch (err) {
			if (!active) return;
			// A transient error while polling: keep trying unless the session is gone
			const apiErr = apiError(err);
			if (apiErr && (apiErr.status === 401 || apiErr.status === 403)) {
				active = false;
				onChange({ phase: 'failed', errorCode: apiErr.code });
				return;
			}
			schedule();
		}
	}

	function stop() {
		active = false;
		if (handle !== null) timers.clearTimeout(handle);
		handle = null;
	}

	return {
		async start(username: string) {
			stop();
			const trimmed = username.trim();
			if (!trimmed) return;
			active = true;
			onChange({ phase: 'running', status: null });
			try {
				await api.startBggImport(trimmed);
			} catch (err) {
				active = false;
				onChange({ phase: 'failed', errorCode: errorCodeOf(err) });
				return;
			}
			if (active) schedule();
		},
		async resume() {
			stop();
			active = true;
			await poll();
		},
		stop
	};
}
