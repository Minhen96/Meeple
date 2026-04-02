<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { setupApi, type SetupStatus, type CsvCheckResult } from '$lib/api/setup';

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

	function fmt(n: number) { return n.toLocaleString(); }
</script>

<!-- Backdrop -->
<button class="fixed inset-0 bg-black/50 z-40" onclick={onClose} aria-label="Close"></button>

<!-- Sheet -->
<div class="fixed inset-x-0 bottom-0 z-50 bg-surface rounded-t-3xl shadow-2xl max-h-[90vh] overflow-y-auto">
	<div class="flex justify-center pt-3 pb-1">
		<div class="w-10 h-1 bg-on-surface/20 rounded-full"></div>
	</div>

	<div class="px-6 pb-10 pt-2 space-y-4">
		<!-- Header -->
		<div class="flex items-center justify-between">
			<div>
				<h2 class="text-xl font-extrabold font-headline">System Setup</h2>
				<p class="text-xs text-on-surface-variant mt-0.5">Auto-refreshes every 5 s</p>
			</div>
			<button onclick={onClose} class="p-2 rounded-full hover:bg-surface-container-high transition-colors">
				<span class="material-symbols-outlined text-on-surface-variant">close</span>
			</button>
		</div>

		{#if error}
			<div class="bg-error-container text-on-error-container rounded-2xl p-4 text-sm">
				Could not load setup status. Check backend connectivity.
			</div>
		{:else if !status}
			{#each [1, 2, 3] as _}
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
						<span class="material-symbols-outlined text-[18px] text-primary" style="font-variation-settings:'FILL' 1">check_circle</span>
					{:else}
						<span class="material-symbols-outlined text-[18px] text-on-surface-variant animate-spin">progress_activity</span>
					{/if}
					<span class="font-bold text-sm flex-1">Game Catalog</span>
					<button
						onclick={() => start('import')}
						disabled={busy['import']}
						class="text-xs font-bold px-3 py-1 rounded-full bg-primary/10 text-primary hover:bg-primary/20 disabled:opacity-40 transition-colors"
					>
						{busy['import'] ? 'Starting…' : status.catalog.imported ? 'Re-import' : 'Start'}
					</button>
				</div>
				<div class="h-2 w-full bg-surface-container-high rounded-full overflow-hidden">
					<div class="h-full rounded-full transition-all duration-700 {status.catalog.imported ? 'bg-primary' : 'bg-on-surface/20'}"
						style="width:{status.catalog.imported ? 100 : 0}%"></div>
				</div>
				<p class="text-xs text-on-surface-variant">
					{status.catalog.imported ? `${fmt(status.catalog.totalGames)} games imported` : status.catalog.totalGames > 0 ? `${fmt(status.catalog.totalGames)} games found — importing…` : 'Waiting for SEED_CSV_URL…'}
				</p>
				<!-- CSV probe -->
				<div class="flex items-center gap-2 pt-1">
					<button
						onclick={runCheckCsv}
						disabled={csvChecking}
						class="text-xs font-bold px-3 py-1 rounded-full bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest disabled:opacity-40 transition-colors"
					>{csvChecking ? 'Checking…' : 'Check CSV Access'}</button>
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
						<span class="material-symbols-outlined text-[18px] text-primary" style="font-variation-settings:'FILL' 1">check_circle</span>
					{:else if status.hydration.running}
						<span class="material-symbols-outlined text-[18px] text-secondary animate-spin">progress_activity</span>
					{:else}
						<span class="material-symbols-outlined text-[18px] text-on-surface/30">radio_button_unchecked</span>
					{/if}
					<span class="font-bold text-sm flex-1">BGG Hydration</span>
					{#if status.hydration.percentDone < 100}
						<span class="text-xs font-bold text-secondary mr-1">{status.hydration.percentDone}%</span>
					{/if}
					{#if status.hydration.running && !status.hydration.stopRequested}
						<button
							onclick={() => stop('hydrate')}
							disabled={busy['stop_hydrate']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-error/10 text-error hover:bg-error/20 disabled:opacity-40 transition-colors"
						>{busy['stop_hydrate'] ? 'Stopping…' : 'Stop'}</button>
					{:else}
						<button
							onclick={() => start('hydrate')}
							disabled={busy['hydrate']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-secondary/10 text-secondary hover:bg-secondary/20 disabled:opacity-40 transition-colors"
						>{busy['hydrate'] ? 'Starting…' : 'Start'}</button>
					{/if}
				</div>
				<div class="h-2 w-full bg-surface-container-high rounded-full overflow-hidden">
					<div class="h-full bg-secondary rounded-full transition-all duration-700" style="width:{status.hydration.percentDone}%"></div>
				</div>
				<p class="text-xs text-on-surface-variant">
					{fmt(status.hydration.hydrated)} / {fmt(status.hydration.total)} hydrated
					{#if status.hydration.stopRequested}&nbsp;· <span class="text-error">stop requested</span>{/if}
				</p>
			</div>

			<!-- Step 3: Rulebook Pump -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.rulebooks.percentDone >= 100}
						<span class="material-symbols-outlined text-[18px] text-primary" style="font-variation-settings:'FILL' 1">check_circle</span>
					{:else if status.rulebooks.running}
						<span class="material-symbols-outlined text-[18px] text-tertiary animate-spin">progress_activity</span>
					{:else}
						<span class="material-symbols-outlined text-[18px] text-on-surface/30">radio_button_unchecked</span>
					{/if}
					<span class="font-bold text-sm flex-1">Rulebook Pump</span>
					{#if status.rulebooks.percentDone < 100}
						<span class="text-xs font-bold text-tertiary mr-1">{status.rulebooks.percentDone}%</span>
					{/if}
					{#if status.rulebooks.running && !status.rulebooks.stopRequested}
						<button
							onclick={() => stop('rulebooks')}
							disabled={busy['stop_rulebooks']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-error/10 text-error hover:bg-error/20 disabled:opacity-40 transition-colors"
						>{busy['stop_rulebooks'] ? 'Stopping…' : 'Stop'}</button>
					{:else}
						<button
							onclick={() => start('rulebooks')}
							disabled={busy['rulebooks']}
							class="text-xs font-bold px-3 py-1 rounded-full bg-tertiary/10 text-tertiary hover:bg-tertiary/20 disabled:opacity-40 transition-colors"
						>{busy['rulebooks'] ? 'Starting…' : 'Start'}</button>
					{/if}
				</div>
				<div class="h-2 w-full bg-surface-container-high rounded-full overflow-hidden">
					<div class="h-full bg-tertiary rounded-full transition-all duration-700" style="width:{status.rulebooks.percentDone}%"></div>
				</div>
				<p class="text-xs text-on-surface-variant">
					{fmt(status.rulebooks.approved)} approved · {fmt(status.rulebooks.ingesting)} ingesting · target {fmt(status.rulebooks.target)}
					{#if status.rulebooks.stopRequested}&nbsp;· <span class="text-error">stop requested</span>{/if}
				</p>
			</div>

			<!-- Reset all -->
			<div class="pt-1">
				{#if confirmReset}
					<p class="text-xs text-error text-center mb-3">Clears all flags. Use Start buttons to re-run each step.</p>
					<div class="flex gap-3">
						<button onclick={() => (confirmReset = false)}
							class="flex-1 py-3 bg-surface-container-high text-on-surface font-bold text-sm rounded-2xl">Cancel</button>
						<button onclick={handleReset} disabled={busy['reset']}
							class="flex-1 py-3 bg-error text-on-error font-bold text-sm rounded-2xl disabled:opacity-50">
							{busy['reset'] ? 'Resetting…' : 'Confirm Reset'}</button>
					</div>
				{:else}
					<button onclick={handleReset}
						class="w-full py-3 bg-surface-container-high text-on-surface-variant font-bold text-sm rounded-2xl hover:bg-error/10 hover:text-error transition-colors">
						Reset All Flags
					</button>
				{/if}
			</div>
		{/if}
	</div>
</div>
