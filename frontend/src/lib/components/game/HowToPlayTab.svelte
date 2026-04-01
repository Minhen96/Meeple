<script lang="ts">
	import { onMount } from 'svelte';
	import { rulebookApi } from '$lib/api/rulebook';

	interface Props {
		gameId: string;
		onOpenAssistant: () => void;
	}
	let { gameId, onOpenAssistant }: Props = $props();

	type RulebookState = 'loading' | 'no_rulebook' | 'generating' | 'ready' | 'error';
	let rulebookState: RulebookState = $state('loading');
	let generating: boolean = $state(false);

	onMount(async () => {
		try {
			const { hasRulebook } = await rulebookApi.getStatus(gameId);
			rulebookState = hasRulebook ? 'ready' : 'no_rulebook';
		} catch {
			rulebookState = 'error';
		}
	});

	async function handleGenerate() {
		generating = true;
		try {
			const result = await rulebookApi.generate(gameId);
			if (result.status === 'generating') {
				rulebookState = 'generating';
			} else if (result.status === 'already_done') {
				rulebookState = 'ready';
			} else {
				// not_found — no PDF source available
				rulebookState = 'no_rulebook';
			}
		} catch {
			// keep current state, stop spinner
		} finally {
			generating = false;
		}
	}
</script>

<div class="py-4 space-y-8 pb-12">
	<!-- Hero Header -->
	<div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-primary/10 via-background to-secondary/5 border border-outline-variant/10 p-6">
		<div class="relative z-10 flex items-start justify-between">
			<div class="space-y-1">
				<div class="flex items-center gap-2 text-primary font-black uppercase tracking-widest text-[10px]">
					<span class="material-symbols-outlined text-[16px]">auto_awesome</span>
					AI Rule Extraction
				</div>
				<h2 class="text-xl font-extrabold text-on-surface">How to Play</h2>
				<p class="text-xs text-on-surface-variant max-w-[240px] leading-relaxed">
					Follow these essential rules to get the game started quickly.
				</p>
			</div>
			<div class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-primary/40 rotate-12">
				<span class="material-symbols-outlined text-[40px]">menu_book</span>
			</div>
		</div>
		<div class="absolute -right-4 -bottom-4 w-32 h-32 bg-primary/5 rounded-full blur-3xl"></div>
	</div>

	<!-- States -->
	{#if rulebookState === 'loading'}
		<!-- Skeleton -->
		<div class="space-y-6">
			{#each [1, 2, 3] as _}
				<div class="space-y-3 animate-pulse">
					<div class="flex items-center gap-3">
						<div class="w-10 h-10 rounded-xl bg-surface-container-high"></div>
						<div class="h-4 w-32 rounded-full bg-surface-container-high"></div>
					</div>
					<div class="pl-13 space-y-2">
						<div class="h-3 rounded-full bg-surface-container-low/50 w-full"></div>
						<div class="h-3 rounded-full bg-surface-container-low/50 w-5/6"></div>
					</div>
				</div>
			{/each}
		</div>

	{:else if rulebookState === 'no_rulebook'}
		<!-- Generate Rules CTA -->
		<div class="rounded-3xl border border-outline-variant/10 bg-surface-container-low/30 p-8 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-on-surface-variant/40">
				<span class="material-symbols-outlined text-[36px]">find_in_page</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">No rulebook yet</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					Generate AI-powered rules by fetching the official rulebook PDF.
				</p>
			</div>
			<button
				onclick={handleGenerate}
				disabled={generating}
				class="flex items-center gap-2 px-5 py-2.5 rounded-2xl bg-primary text-on-primary text-sm font-bold disabled:opacity-50 transition-opacity"
			>
				{#if generating}
					<span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
					Fetching…
				{:else}
					<span class="material-symbols-outlined text-[18px]">bolt</span>
					Generate Rules
				{/if}
			</button>
		</div>

	{:else if rulebookState === 'generating'}
		<!-- Ingestion in progress -->
		<div class="rounded-3xl border border-primary/20 bg-primary/5 p-8 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
				<span class="material-symbols-outlined text-[36px] animate-spin">progress_activity</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">Generating rules…</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					We found the rulebook PDF and are processing it. This usually takes under a minute. Check back shortly.
				</p>
			</div>
		</div>

	{:else if rulebookState === 'ready'}
		<!-- Placeholder until HowToPlayExtractionService (Step 10) is built -->
		<div class="rounded-3xl border border-outline-variant/10 bg-surface-container-low/30 p-8 flex flex-col items-center text-center gap-4">
			<div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
				<span class="material-symbols-outlined text-[36px]">check_circle</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">Rulebook ready</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					The rulebook has been indexed. Use the AI Assistant below to ask any question about the rules.
				</p>
			</div>
		</div>

	{:else if rulebookState === 'error'}
		<p class="text-center text-xs text-error py-8">Failed to load rulebook status. Try refreshing.</p>
	{/if}

	<!-- AI Assistant Call-to-action -->
	<button
		onclick={onOpenAssistant}
		class="w-full bg-tertiary-container/30 rounded-3xl p-6 border border-tertiary/10 flex flex-col items-center text-center gap-3 mt-4 hover:bg-tertiary-container/40 transition-colors"
	>
		<div class="w-12 h-12 rounded-full bg-tertiary/10 flex items-center justify-center text-tertiary">
			<span class="material-symbols-outlined">smart_toy</span>
		</div>
		<div class="space-y-1">
			<h4 class="font-bold text-on-tertiary-container">Still have questions?</h4>
			<p class="text-[11px] text-on-tertiary-container/70 leading-relaxed px-4">
				Our AI Assistant has read the full rulebook and can answer specific edge cases.
			</p>
		</div>
	</button>
</div>

<style>
	.pl-13 {
		padding-left: 3.25rem;
	}
</style>
