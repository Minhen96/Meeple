<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { setupApi, type SetupStatus } from '$lib/api/setup';

	interface Props {
		onClose: () => void;
	}
	let { onClose }: Props = $props();

	let status = $state<SetupStatus | null>(null);
	let error = $state(false);
	let resetting = $state(false);
	let confirmReset = $state(false);
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

	async function handleReset() {
		if (!confirmReset) {
			confirmReset = true;
			return;
		}
		resetting = true;
		try {
			await setupApi.reset();
			confirmReset = false;
			await load();
		} finally {
			resetting = false;
		}
	}

	function fmt(n: number) {
		return n.toLocaleString();
	}
</script>

<!-- Backdrop -->
<button
	class="fixed inset-0 bg-black/50 z-40"
	onclick={onClose}
	aria-label="Close"
></button>

<!-- Sheet -->
<div class="fixed inset-x-0 bottom-0 z-50 bg-surface rounded-t-3xl shadow-2xl max-h-[90vh] overflow-y-auto">
	<!-- Handle -->
	<div class="flex justify-center pt-3 pb-1">
		<div class="w-10 h-1 bg-on-surface/20 rounded-full"></div>
	</div>

	<div class="px-6 pb-10 pt-2 space-y-6">
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
			<!-- Loading skeleton -->
			{#each [1, 2, 3] as _}
				<div class="bg-surface-container-low rounded-2xl p-5 space-y-3 animate-pulse">
					<div class="h-4 w-32 bg-surface-container-high rounded-full"></div>
					<div class="h-2.5 w-full bg-surface-container-high rounded-full"></div>
					<div class="h-3 w-24 bg-surface-container-high rounded-full"></div>
				</div>
			{/each}
		{:else}
			<!-- Step 1: Catalog -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.catalog.imported}
						<span class="material-symbols-outlined text-[20px] text-primary" style="font-variation-settings:'FILL' 1">check_circle</span>
					{:else}
						<span class="material-symbols-outlined text-[20px] text-on-surface-variant animate-spin">progress_activity</span>
					{/if}
					<span class="font-bold text-sm">Game Catalog</span>
				</div>
				<div class="h-2 w-full bg-surface-container-high rounded-full overflow-hidden">
					<div
						class="h-full rounded-full transition-all duration-700 {status.catalog.imported ? 'bg-primary' : 'bg-on-surface/20'}"
						style="width: {status.catalog.imported ? 100 : 0}%"
					></div>
				</div>
				<p class="text-xs text-on-surface-variant">
					{#if status.catalog.imported}
						{fmt(status.catalog.totalGames)} games imported
					{:else if status.catalog.totalGames > 0}
						{fmt(status.catalog.totalGames)} games in DB — importing...
					{:else}
						Waiting for SEED_CSV_URL download...
					{/if}
				</p>
			</div>

			<!-- Step 2: BGG Hydration -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.hydration.percentDone >= 100}
						<span class="material-symbols-outlined text-[20px] text-primary" style="font-variation-settings:'FILL' 1">check_circle</span>
					{:else if status.hydration.started}
						<span class="material-symbols-outlined text-[20px] text-secondary animate-spin">progress_activity</span>
					{:else}
						<span class="material-symbols-outlined text-[20px] text-on-surface/30">radio_button_unchecked</span>
					{/if}
					<span class="font-bold text-sm">BGG Hydration</span>
					{#if status.hydration.started && status.hydration.percentDone < 100}
						<span class="ml-auto text-xs font-bold text-secondary">{status.hydration.percentDone}%</span>
					{/if}
				</div>
				<div class="h-2 w-full bg-surface-container-high rounded-full overflow-hidden">
					<div
						class="h-full bg-secondary rounded-full transition-all duration-700"
						style="width: {status.hydration.percentDone}%"
					></div>
				</div>
				<p class="text-xs text-on-surface-variant">
					{fmt(status.hydration.hydrated)} / {fmt(status.hydration.total)} games hydrated
					{#if status.hydration.unhydrated > 0}
						· {fmt(status.hydration.unhydrated)} remaining
					{/if}
				</p>
			</div>

			<!-- Step 3: Rulebook Pump -->
			<div class="bg-surface-container-low rounded-2xl p-5 space-y-3">
				<div class="flex items-center gap-2">
					{#if status.rulebooks.percentDone >= 100}
						<span class="material-symbols-outlined text-[20px] text-primary" style="font-variation-settings:'FILL' 1">check_circle</span>
					{:else if status.rulebooks.pumpStarted}
						<span class="material-symbols-outlined text-[20px] text-tertiary animate-spin">progress_activity</span>
					{:else}
						<span class="material-symbols-outlined text-[20px] text-on-surface/30">radio_button_unchecked</span>
					{/if}
					<span class="font-bold text-sm">Rulebook Pump</span>
					{#if status.rulebooks.pumpStarted && status.rulebooks.percentDone < 100}
						<span class="ml-auto text-xs font-bold text-tertiary">{status.rulebooks.percentDone}%</span>
					{/if}
				</div>
				<div class="h-2 w-full bg-surface-container-high rounded-full overflow-hidden">
					<div
						class="h-full bg-tertiary rounded-full transition-all duration-700"
						style="width: {status.rulebooks.percentDone}%"
					></div>
				</div>
				<p class="text-xs text-on-surface-variant">
					{fmt(status.rulebooks.approved)} / {fmt(status.rulebooks.target)} rulebooks approved
				</p>
			</div>

			<!-- Reset -->
			<div class="pt-2">
				{#if confirmReset}
					<p class="text-xs text-error text-center mb-3">
						This clears all flags. Restart the server to re-run from scratch.
					</p>
					<div class="flex gap-3">
						<button
							onclick={() => (confirmReset = false)}
							class="flex-1 py-3 bg-surface-container-high text-on-surface font-bold text-sm rounded-2xl"
						>Cancel</button>
						<button
							onclick={handleReset}
							disabled={resetting}
							class="flex-1 py-3 bg-error text-on-error font-bold text-sm rounded-2xl disabled:opacity-50"
						>
							{resetting ? 'Resetting...' : 'Confirm Reset'}
						</button>
					</div>
				{:else}
					<button
						onclick={handleReset}
						class="w-full py-3 bg-surface-container-high text-on-surface-variant font-bold text-sm rounded-2xl hover:bg-error/10 hover:text-error transition-colors"
					>
						Reset Setup Flags
					</button>
				{/if}
			</div>
		{/if}
	</div>
</div>
