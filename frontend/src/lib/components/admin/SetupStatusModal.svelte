<script lang="ts">
	import ProgressBar from '$lib/components/ui/ProgressBar.svelte';
	import { onMount, onDestroy } from 'svelte';
	import { setupApi, type SetupStatus, type CsvCheckResult } from '$lib/api/setup';
	import { m } from '$lib/i18n';
	import { formatNumber, formatPercent } from '$lib/i18n/format';

	interface Props {
		onClose: () => void;
	}
	let { onClose }: Props = $props();

	let status = $state<SetupStatus | null>(null);
	let error = $state(false);
	let busy = $state<Record<string, boolean>>({});
	let confirmReset = $state(false);
	let csvCheck = $state<CsvCheckResult | null>(null);
	let csvChecking = $state(false);
	let interval: ReturnType<typeof setInterval>;

	async function load() {
		try {
			status = await setupApi.getStatus();
			error = false;
		} catch {
			error = true;
		}
	}

	onMount(() => {
		load();
		interval = setInterval(load, 5000);
	});

	onDestroy(() => clearInterval(interval));

	async function runCheckCsv() {
		csvChecking = true;
		csvCheck = null;
		try {
			csvCheck = await setupApi.checkCsv();
		} finally {
			csvChecking = false;
		}
	}

	async function start(step: 'import' | 'hydrate' | 'rulebooks') {
		busy = { ...busy, [step]: true };
		try {
			await setupApi.start(step);
			await load();
		} finally {
			busy = { ...busy, [step]: false };
		}
	}

	async function stop(step: 'hydrate' | 'rulebooks') {
		busy = { ...busy, [`stop_${step}`]: true };
		try {
			await setupApi.stop(step);
			await load();
		} finally {
			busy = { ...busy, [`stop_${step}`]: false };
		}
	}

	async function handleReset() {
		if (!confirmReset) { confirmReset = true; return; }
		busy = { ...busy, reset: true };
		try {
			await setupApi.reset();
			confirmReset = false;
			await load();
		} finally {
			busy = { ...busy, reset: false };
		}
	}

	const fmt = (n: number) => formatNumber(n);
</script>

<!-- Backdrop -->
<button class="fixed inset-0 bg-black/50 z-40" onclick={onClose} aria-label={m('common.close')}></button>

<!-- Sheet -->
<div class="fixed inset-x-0 bottom-0 z-50 bg-surface rounded-t-3xl shadow-2xl max-h-[90vh] overflow-y-auto">
	<div class="flex justify-center pt-3 pb-1">
		<div class="w-10 h-1 bg-on-surface/20 rounded-full"></div>
	</div>

	<div class="px-6 pb-10 pt-2 space-y-4">
		<!-- Header -->
		<div class="flex items-center justify-between">
			<div>
				<h2 class="text-xl font-extrabold font-headline">{m('admin.setup.title')}</h2>
				<p class="text-xs text-on-surface-variant mt-0.5">{m('admin.setup.autoRefresh', { seconds: 5 })}</p>
			</div>
			<button onclick={onClose} aria-label={m('common.close')} class="p-2 rounded-full hover:bg-surface-container-high transition-colors">
				<span class="material-symbols-outlined text-on-surface-variant">close</span>
			</button>
		</div>

		{#if error}
			<div class="bg-error-container text-on-error-container rounded-2xl p-4 text-sm">
				{m('admin.setup.loadFailed')}
			</div>
		{:else if !status}
			{#each [1, 2, 3] as n (n)}
				<div class="bg-surface-container-low rounded-2xl p-5 space-y-3 animate-pulse">
					<div class="h-4 w-32 bg-surface-container-high rounded-full"></div>
					<div class="h-2.5 w-full bg-surface-container-high rounded-full"></div>
				</div>
			{/each}
		{:else}

			<!-- Step 1: Catalog -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.catalog.imported}
						<span class="icon-filled material-symbols-outlined text-[18px] text-primary">check_circle</span>
					{:else}
						<span class="material-symbols-outlined text-[18px] text-on-surface-variant animate-spin">progress_activity</span>
					{/if}
					<span class="font-bold text-sm flex-1">{m('admin.setup.catalog')}</span>
					<button
						onclick={() => start('import')}
						disabled={busy['import']}
						class="text-xs font-bold px-3 py-1 rounded-full bg-primary/10 text-primary hover:bg-primary/20 disabled:opacity-40 transition-colors"
					>
						{busy['import'] ? m('admin.setup.starting') : status.catalog.imported ? m('admin.setup.reimport') : m('admin.setup.start')}
					</button>
				</div>
				<ProgressBar
					value={status.catalog.imported ? 100 : 0}
					tone={status.catalog.imported ? 'primary' : 'muted'}
					label={m('admin.setup.catalogProgress')}
				/>
				<p class="text-xs text-on-surface-variant">
					{status.catalog.imported
					? m('admin.setup.catalogImported', { count: fmt(status.catalog.totalGames) })
					: status.catalog.totalGames > 0
						? m('admin.setup.catalogImporting', { count: fmt(status.catalog.totalGames) })
						: m('admin.setup.catalogWaiting')}
				</p>
				<!-- CSV probe -->
				<div class="flex items-center gap-2 pt-1">
					<button
						onclick={runCheckCsv}
						disabled={csvChecking}
						class="text-xs font-bold px-3 py-1 rounded-full bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest disabled:opacity-40 transition-colors"
					>{csvChecking ? m('admin.setup.checking') : m('admin.setup.checkCsv')}</button>
					{#if csvCheck}
						<span class="text-xs font-bold {csvCheck.pass ? 'text-primary' : 'text-error'}">
							{csvCheck.pass ? `✓ ${csvCheck.sizeMb}` : `✗ ${csvCheck.error ?? csvCheck.verdict}`}
						</span>
					{/if}
				</div>
			</div>

			<!-- Step 2: BGG Hydration -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.hydration.percentDone >= 100}
						<span class="icon-filled material-symbols-outlined text-[18px] text-primary">check_circle</span>
					{:else if status.hydration.running}
						<span class="material-symbols-outlined text-[18px] text-secondary animate-spin">progress_activity</span>
					{:else}
						<span class="material-symbols-outlined text-[18px] text-on-surface/30">radio_button_unchecked</span>
					{/if}
					<span class="font-bold text-sm flex-1">{m('admin.setup.hydration')}</span>
					{#if status.hydration.percentDone < 100}
						<span class="text-xs font-bold text-secondary mr-1">{formatPercent(status.hydration.percentDone)}</span>
					{/if}
					{#if status.hydration.running && !status.hydration.stopRequested}
						<button
							onclick={() => stop('hydrate')}
							disabled={busy['stop_hydrate']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-error/10 text-error hover:bg-error/20 disabled:opacity-40 transition-colors"
						>{busy['stop_hydrate'] ? m('admin.setup.stopping') : m('admin.setup.stop')}</button>
					{:else}
						<button
							onclick={() => start('hydrate')}
							disabled={busy['hydrate']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-secondary/10 text-secondary hover:bg-secondary/20 disabled:opacity-40 transition-colors"
						>{busy['hydrate'] ? m('admin.setup.starting') : m('admin.setup.start')}</button>
					{/if}
				</div>
				<ProgressBar value={status.hydration.percentDone} tone="secondary" label={m('admin.setup.hydrationProgress')} />
				<p class="text-xs text-on-surface-variant">
					{m('admin.setup.hydrated', { done: fmt(status.hydration.hydrated), total: fmt(status.hydration.total) })}
					{#if status.hydration.stopRequested}&nbsp;· <span class="text-error">{m('admin.setup.stopRequested')}</span>{/if}
				</p>
			</div>

			<!-- Step 3: Rulebook Pump -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.rulebooks.percentDone >= 100}
						<span class="icon-filled material-symbols-outlined text-[18px] text-primary">check_circle</span>
					{:else if status.rulebooks.running}
						<span class="material-symbols-outlined text-[18px] text-tertiary animate-spin">progress_activity</span>
					{:else}
						<span class="material-symbols-outlined text-[18px] text-on-surface/30">radio_button_unchecked</span>
					{/if}
					<span class="font-bold text-sm flex-1">{m('admin.setup.rulebooks')}</span>
					{#if status.rulebooks.percentDone < 100}
						<span class="text-xs font-bold text-tertiary mr-1">{formatPercent(status.rulebooks.percentDone)}</span>
					{/if}
					{#if status.rulebooks.running && !status.rulebooks.stopRequested}
						<button
							onclick={() => stop('rulebooks')}
							disabled={busy['stop_rulebooks']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-error/10 text-error hover:bg-error/20 disabled:opacity-40 transition-colors"
						>{busy['stop_rulebooks'] ? m('admin.setup.stopping') : m('admin.setup.stop')}</button>
					{:else}
						<button
							onclick={() => start('rulebooks')}
							disabled={busy['rulebooks']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-tertiary/10 text-tertiary hover:bg-tertiary/20 disabled:opacity-40 transition-colors"
						>{busy['rulebooks'] ? m('admin.setup.starting') : m('admin.setup.start')}</button>
					{/if}
				</div>
				<ProgressBar value={status.rulebooks.percentDone} tone="tertiary" label={m('admin.setup.rulebooksProgress')} />
				<p class="text-xs text-on-surface-variant">
					{m('admin.setup.rulebooksStats', {
					approved: fmt(status.rulebooks.approved),
					ingesting: fmt(status.rulebooks.ingesting),
					target: fmt(status.rulebooks.target)
				})}
					{#if status.rulebooks.stopRequested}&nbsp;· <span class="text-error">{m('admin.setup.stopRequested')}</span>{/if}
				</p>
			</div>

			<!-- Reset all -->
			<div class="pt-1">
				{#if confirmReset}
					<p class="text-xs text-error text-center mb-3">{m('admin.setup.resetHint')}</p>
					<div class="flex gap-3">
						<button onclick={() => (confirmReset = false)}
							class="flex-1 py-3 bg-surface-container-high text-on-surface font-bold text-sm rounded-2xl">{m('common.cancel')}</button>
						<button onclick={handleReset} disabled={busy['reset']}
							class="flex-1 py-3 bg-error text-on-error font-bold text-sm rounded-2xl disabled:opacity-50">
							{busy['reset'] ? m('admin.setup.resetting') : m('admin.setup.confirmReset')}</button>
					</div>
				{:else}
					<button onclick={handleReset}
						class="w-full py-3 bg-surface-container-high text-on-surface-variant font-bold text-sm rounded-2xl hover:bg-error/10 hover:text-error transition-colors">
						{m('admin.setup.reset')}
					</button>
				{/if}
			</div>
		{/if}
	</div>
</div>
