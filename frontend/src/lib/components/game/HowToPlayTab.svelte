<script lang="ts">
	import { onMount } from "svelte";
	import { rulebookApi } from "$lib/api/rulebook";
	import { adminApi } from "$lib/api/admin";
	import { howToPlayApi } from "$lib/api/howtoplay";
	import { currentUser } from "$lib/stores/auth";
	import { toast } from "svelte-sonner";
	import type { HowToPlayContent } from "$lib/types";

	interface Props {
		gameId: string;
		onOpenAssistant: () => void;
	}
	let { gameId, onOpenAssistant }: Props = $props();

	const isAdmin = $derived($currentUser?.isAdmin ?? false);

	type RulebookState =
		| "loading"
		| "no_rulebook"
		| "generating"
		| "pending_review"
		| "ready"
		| "error";
	let rulebookState: RulebookState = $state("loading");
	let generating: boolean = $state(false);
	let uploading: boolean = $state(false);
	let myQueuePosition: number | null = $state(null);

	// How-to-play content
	type HowToPlayState = "idle" | "loading" | "generating" | "ready" | "error";
	let howToPlayState: HowToPlayState = $state("idle");
	let howToPlayData: HowToPlayContent | null = $state(null);
	let howToPlaySourceMode: string | null = $state(null);
	let howToPlayDisclaimer: string | null = $state(null);
	let howToPlayRulebookUrl: string | null = $state(null);
	let pollInterval: ReturnType<typeof setInterval> | null = null;
	let rulebookPollInterval: ReturnType<typeof setInterval> | null = null;

	// FAQ expand state
	let expandedFaq = $state<Set<number>>(new Set());

	// File input refs
	let fileInput: HTMLInputElement = $state() as HTMLInputElement;
	let adminFileInput: HTMLInputElement = $state() as HTMLInputElement;

	onMount(() => {
		initRulebookStatus();
		return () => {
			if (pollInterval !== null) clearInterval(pollInterval);
			if (rulebookPollInterval !== null) clearInterval(rulebookPollInterval);
		};
	});

	async function initRulebookStatus() {
		try {
			const status = await rulebookApi.getStatus(gameId);
			if (status.hasRulebook) {
				rulebookState = "ready";
				fetchHowToPlay();
			} else if (status.isIngesting) {
				rulebookState = "generating";
				startRulebookPolling();
			} else if (status.myStatus === "pending_review") {
				rulebookState = "pending_review";
				myQueuePosition = status.myQueuePosition;
			} else {
				rulebookState = "no_rulebook";
			}
		} catch {
			rulebookState = "error";
		}
	}

	async function fetchHowToPlay() {
		howToPlayState = "loading";
		try {
			const res = await howToPlayApi.get(gameId);
			if (res.status === "ready" && res.data) {
				howToPlayState = "ready";
				howToPlayData = res.data;
				howToPlaySourceMode = res.sourceMode;
				howToPlayDisclaimer = res.disclaimer;
				howToPlayRulebookUrl = res.rulebookUrl;
			} else {
				howToPlayState = "generating";
				startPolling();
			}
		} catch {
			howToPlayState = "error";
		}
	}

	function startPolling() {
		if (pollInterval !== null) return;
		pollInterval = setInterval(async () => {
			try {
				const res = await howToPlayApi.get(gameId);
				if (res.status === "ready" && res.data) {
					clearInterval(pollInterval!);
					pollInterval = null;
					howToPlayState = "ready";
					howToPlayData = res.data;
					howToPlaySourceMode = res.sourceMode;
					howToPlayDisclaimer = res.disclaimer;
					howToPlayRulebookUrl = res.rulebookUrl;
				}
			} catch {
				clearInterval(pollInterval!);
				pollInterval = null;
				howToPlayState = "error";
			}
		}, 2000);
	}

	function startRulebookPolling() {
		if (rulebookPollInterval !== null) return;
		rulebookPollInterval = setInterval(async () => {
			try {
				const status = await rulebookApi.getStatus(gameId);
				if (status.hasRulebook) {
					clearInterval(rulebookPollInterval!);
					rulebookPollInterval = null;
					rulebookState = "ready";
					fetchHowToPlay();
				}
			} catch {
				clearInterval(rulebookPollInterval!);
				rulebookPollInterval = null;
				rulebookState = "error";
			}
		}, 3000);
	}

	async function handleGenerate() {
		generating = true;
		try {
			const result = await rulebookApi.generate(gameId);
			if (result.status === "generating") {
				rulebookState = "generating";
				startRulebookPolling();
			} else if (result.status === "already_done") {
				rulebookState = "ready";
				fetchHowToPlay();
			} else if (result.status === "not_found") {
				toast.error("No rulebook found online. Generating from AI knowledge…");
				rulebookState = "ready";
				fetchHowToPlay();
			}
		} catch {
			toast.error("Could not fetch rulebook");
		} finally {
			generating = false;
		}
	}

	async function handleUserUpload(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		uploading = true;
		try {
			const result = await rulebookApi.upload(gameId, file);
			if (result.status === "queued") {
				rulebookState = "pending_review";
				myQueuePosition = result.queuePosition ?? null;
				toast.success(
					"PDF submitted! An admin will review it shortly.",
				);
			} else if (result.status === "already_done") {
				rulebookState = "ready";
				fetchHowToPlay();
			}
		} catch {
			toast.error("Upload failed. File must be a PDF under 25 MB.");
		} finally {
			uploading = false;
			fileInput.value = "";
		}
	}

	async function handleAdminUpload(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		uploading = true;
		try {
			await adminApi.uploadRulebookForGame(gameId, file);
			rulebookState = "generating";
			toast.success("Uploading and ingesting…");
		} catch {
			toast.error("Admin upload failed.");
		} finally {
			uploading = false;
			adminFileInput.value = "";
		}
	}

	function toggleFaq(i: number) {
		const next = new Set(expandedFaq);
		if (next.has(i)) next.delete(i);
		else next.add(i);
		expandedFaq = next;
	}
</script>

<div class="py-4 space-y-8 pb-12">
	<!-- Hero Header -->
	<div
		class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-primary/10 via-background to-secondary/5 border border-outline-variant/10 p-6"
	>
		<div class="relative z-10 flex items-start justify-between">
			<div class="space-y-1">
				<div
					class="flex items-center gap-2 text-primary font-black uppercase tracking-widest text-[10px]"
				>
					<span class="material-symbols-outlined text-[16px]"
						>auto_awesome</span
					>
					AI Rule Extraction
				</div>
				<h2 class="text-xl font-extrabold text-on-surface">
					How to Play
				</h2>
				<p
					class="text-xs text-on-surface-variant max-w-[240px] leading-relaxed"
				>
					Follow these essential rules to get the game started
					quickly.
				</p>
			</div>
			<div
				class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-primary/40 rotate-12"
			>
				<span class="material-symbols-outlined text-[40px]"
					>menu_book</span
				>
			</div>
		</div>
		<div
			class="absolute -right-4 -bottom-4 w-32 h-32 bg-primary/5 rounded-full blur-3xl"
		></div>
	</div>

	<!-- Rulebook status section -->
	{#if rulebookState === "loading"}
		<div class="space-y-6">
			{#each [1, 2, 3] as _}
				<div class="space-y-3 animate-pulse">
					<div class="flex items-center gap-3">
						<div
							class="w-10 h-10 rounded-xl bg-surface-container-high"
						></div>
						<div
							class="h-4 w-32 rounded-full bg-surface-container-high"
						></div>
					</div>
					<div class="pl-13 space-y-2">
						<div
							class="h-3 rounded-full bg-surface-container-low/50 w-full"
						></div>
						<div
							class="h-3 rounded-full bg-surface-container-low/50 w-5/6"
						></div>
					</div>
				</div>
			{/each}
		</div>
	{:else if rulebookState === "no_rulebook"}
		<div
			class="rounded-3xl border border-outline-variant/10 bg-surface-container-low/30 p-6 flex flex-col items-center text-center gap-4"
		>
			<div
				class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-on-surface-variant/40"
			>
				<span class="material-symbols-outlined text-[36px]"
					>find_in_page</span
				>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">No rulebook yet</h3>
				<p
					class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
				>
					Try auto-fetching from rule-book.org, or upload the PDF
					yourself.
				</p>
			</div>

			<button
				onclick={handleGenerate}
				disabled={generating || uploading}
				class="w-full flex items-center justify-center gap-2 px-5 py-2.5 rounded-2xl bg-primary text-on-primary text-sm font-bold disabled:opacity-50 transition-opacity"
			>
				{#if generating}
					<span
						class="material-symbols-outlined text-[18px] animate-spin"
						>progress_activity</span
					>
					Fetching…
				{:else}
					<span class="material-symbols-outlined text-[18px]"
						>bolt</span
					>
					Generate Rules
				{/if}
			</button>

			<div class="w-full">
				<input
					bind:this={fileInput}
					type="file"
					accept="application/pdf"
					class="hidden"
					onchange={handleUserUpload}
				/>
				<button
					onclick={() => fileInput.click()}
					disabled={generating || uploading}
					class="w-full flex items-center justify-center gap-2 px-5 py-2.5 rounded-2xl bg-surface-container-high text-on-surface text-sm font-bold disabled:opacity-50 transition-opacity"
				>
					{#if uploading}
						<span
							class="material-symbols-outlined text-[18px] animate-spin"
							>progress_activity</span
						>
						Uploading…
					{:else}
						<span class="material-symbols-outlined text-[18px]"
							>upload_file</span
						>
						Upload PDF
					{/if}
				</button>
				<p
					class="text-[10px] text-on-surface-variant text-center mt-1.5"
				>
					PDF only · max 25 MB · goes to admin review
				</p>
			</div>
		</div>
	{:else if rulebookState === "generating"}
		<div
			class="rounded-3xl border border-primary/20 bg-primary/5 p-8 flex flex-col items-center text-center gap-4"
		>
			<div
				class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary"
			>
				<span class="material-symbols-outlined text-[36px] animate-spin"
					>progress_activity</span
				>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">Processing rulebook…</h3>
				<p
					class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
				>
					The PDF is being indexed. This usually takes under a minute.
					Check back shortly.
				</p>
			</div>
		</div>
	{:else if rulebookState === "pending_review"}
		<div
			class="rounded-3xl border border-secondary/20 bg-secondary/5 p-8 flex flex-col items-center text-center gap-4"
		>
			<div
				class="w-16 h-16 rounded-2xl bg-secondary/10 flex items-center justify-center text-secondary"
			>
				<span class="material-symbols-outlined text-[36px]"
					>hourglass_top</span
				>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">PDF under review</h3>
				<p
					class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
				>
					Your upload is in the queue{myQueuePosition !== null
						? ` (#${myQueuePosition + 1})`
						: ""}. Rules will appear once an admin approves it.
				</p>
			</div>
		</div>
	{:else if rulebookState === "ready"}
		<!-- How-to-Play content -->
		{#if howToPlayState === "loading"}
			<div class="space-y-5">
				{#each [1, 2, 3] as _}
					<div
						class="rounded-2xl bg-surface-container-low/40 p-5 space-y-3 animate-pulse"
					>
						<div class="flex items-center gap-3">
							<div
								class="w-8 h-8 rounded-lg bg-surface-container-high"
							></div>
							<div
								class="h-3.5 w-28 rounded-full bg-surface-container-high"
							></div>
						</div>
						<div class="space-y-2 pl-11">
							<div
								class="h-3 rounded-full bg-surface-container-low/60 w-full"
							></div>
							<div
								class="h-3 rounded-full bg-surface-container-low/60 w-4/5"
							></div>
							<div
								class="h-3 rounded-full bg-surface-container-low/60 w-3/5"
							></div>
						</div>
					</div>
				{/each}
			</div>
		{:else if howToPlayState === "generating"}
			<div
				class="rounded-3xl border border-tertiary/20 bg-tertiary/5 p-8 flex flex-col items-center text-center gap-4"
			>
				<div
					class="w-16 h-16 rounded-2xl bg-tertiary/10 flex items-center justify-center text-tertiary"
				>
					<span
						class="material-symbols-outlined text-[36px] animate-spin"
						>progress_activity</span
					>
				</div>
				<div class="space-y-1">
					<h3 class="font-bold text-on-surface">
						Generating your guide…
					</h3>
					<p
						class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
					>
						AI is reading the rulebook and extracting key
						information. This takes about 20–30 seconds.
					</p>
				</div>
			</div>
		{:else if howToPlayState === "ready" && howToPlayData}
			<!-- Source mode badge -->
			{#if howToPlaySourceMode}
				<div class="flex items-center gap-2 flex-wrap">
					<span class="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest px-3 py-1 rounded-full
						{howToPlaySourceMode === 'rulebook' ? 'bg-primary/10 text-primary' : 'bg-amber-400/10 text-amber-500'}">
						<span class="material-symbols-outlined text-[12px]">
							{howToPlaySourceMode === "rulebook" ? "menu_book" : "psychology"}
						</span>
						{howToPlaySourceMode === "rulebook" ? "From Official Rulebook" : "AI General Knowledge"}
					</span>
					{#if howToPlayDisclaimer}
						<span class="text-[10px] text-on-surface-variant opacity-60">{howToPlayDisclaimer}</span>
					{/if}
				</div>
			{/if}

			<!-- 1. Overview -->
			{#if howToPlayData.overview || howToPlayData.objective}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center text-lg">📖</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Overview</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12">
						{howToPlayData.overview ?? howToPlayData.objective}
					</p>
					{#if howToPlayData.overview && howToPlayData.objective}
						<p class="text-sm text-on-surface leading-relaxed pl-12 pt-1">
							<strong>Goal:</strong> {howToPlayData.objective}
						</p>
					{/if}
				</div>
			{/if}

			<!-- 2. What's in the Box -->
			{#if howToPlayData.components?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-surface-container-high flex items-center justify-center text-lg">📦</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">What's in the Box</h3>
					</div>
					<div class="pl-12 flex flex-wrap gap-2">
						{#each howToPlayData.components as comp}
							<span class="text-xs bg-surface-container-high text-on-surface px-3 py-1.5 rounded-xl font-medium">
								{comp.quantity ? `${comp.quantity}× ` : ""}{comp.name}
							</span>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 3. Setup -->
			{#if howToPlayData.setup}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-secondary/10 flex items-center justify-center text-lg">⚙️</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Setup</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.setup}</p>
				</div>
			{/if}

			<!-- 4. Resources -->
			{#if howToPlayData.resources?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-amber-400/10 flex items-center justify-center text-lg">💰</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Resources</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.resources as resource}
							<div>
								<p class="text-sm font-bold text-on-surface">{resource.name}</p>
								{#if resource.usedFor}
									<p class="text-xs text-on-surface-variant leading-relaxed">Used for: {resource.usedFor}</p>
								{/if}
								{#if resource.gainedBy}
									<p class="text-xs text-on-surface-variant leading-relaxed">Gained by: {resource.gainedBy}</p>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 5. Card System -->
			{#if howToPlayData.cardSystem?.exists && (howToPlayData.cardSystem.cardTypes?.length || howToPlayData.cardSystem.deckRules || howToPlayData.cardSystem.handRules)}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-tertiary/10 flex items-center justify-center text-lg">🃏</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Cards</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#if howToPlayData.cardSystem.deckRules}
							<p class="text-xs text-on-surface-variant leading-relaxed"><strong>Deck:</strong> {howToPlayData.cardSystem.deckRules}</p>
						{/if}
						{#if howToPlayData.cardSystem.handRules}
							<p class="text-xs text-on-surface-variant leading-relaxed"><strong>Hand:</strong> {howToPlayData.cardSystem.handRules}</p>
						{/if}
						{#if howToPlayData.cardSystem.cardTypes?.length}
							<div class="space-y-2">
								{#each howToPlayData.cardSystem.cardTypes as ct}
									<div>
										<p class="text-sm font-bold text-on-surface">{ct.name}</p>
										<p class="text-xs text-on-surface-variant leading-relaxed">{ct.description}</p>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			{/if}

			<!-- 6. The Board -->
			{#if howToPlayData.board?.exists && howToPlayData.board.description}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-surface-container-high flex items-center justify-center text-lg">🗺️</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">The Board</h3>
					</div>
					<div class="pl-12 space-y-1">
						{#if howToPlayData.board.type}
							<p class="text-xs font-semibold text-on-surface-variant uppercase tracking-wide">{howToPlayData.board.type}</p>
						{/if}
						<p class="text-sm text-on-surface leading-relaxed">{howToPlayData.board.description}</p>
					</div>
				</div>
			{/if}

			<!-- 7. Player Roles -->
			{#if howToPlayData.roles?.exists && howToPlayData.roles.list?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-secondary/10 flex items-center justify-center text-lg">👤</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Player Roles</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.roles.list as role}
							<div>
								<p class="text-sm font-bold text-on-surface">{role.name}</p>
								<p class="text-xs text-on-surface-variant leading-relaxed">{role.abilities}</p>
								{#if role.winCondition}
									<p class="text-xs text-on-surface-variant leading-relaxed mt-0.5">Win: {role.winCondition}</p>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 8. Actions -->
			{#if howToPlayData.actions?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center text-lg">⚡</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Actions</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.actions as action}
							<div>
								<p class="text-sm font-bold text-on-surface">{action.name}{#if action.type}<span class="text-xs font-normal text-on-surface-variant"> · {action.type}</span>{/if}</p>
								{#if action.cost}
									<p class="text-xs text-on-surface-variant leading-relaxed">Cost: {action.cost}</p>
								{/if}
								{#if action.effect}
									<p class="text-xs text-on-surface-variant leading-relaxed">{action.effect}</p>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 9. Game Flow -->
			{#if howToPlayData.gameStructure?.phases?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-secondary/10 flex items-center justify-center text-lg">🔄</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Game Flow</h3>
					</div>
					<div class="pl-12 space-y-4">
						{#if howToPlayData.gameStructure.turnOrder}
							<p class="text-xs text-on-surface-variant leading-relaxed">{howToPlayData.gameStructure.turnOrder}</p>
						{/if}
						{#each howToPlayData.gameStructure.phases as phase, i}
							<div class="relative pl-5">
								<div class="absolute left-0 top-1 w-4 h-4 rounded-full bg-secondary/20 flex items-center justify-center">
									<span class="text-[8px] font-black text-secondary">{i + 1}</span>
								</div>
								<p class="text-sm font-bold text-on-surface">{phase.name}</p>
								{#if phase.description}
									<p class="text-xs text-on-surface-variant leading-relaxed mt-0.5">{phase.description}</p>
								{/if}
								{#if phase.actions?.length}
									<ul class="mt-1.5 space-y-0.5">
										{#each phase.actions as action}
											<li class="text-xs text-on-surface-variant flex items-start gap-1.5">
												<span class="material-symbols-outlined text-[10px] mt-0.5 text-secondary/60">arrow_forward</span>
												{action}
											</li>
										{/each}
									</ul>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 10. Core Rules -->
			{#if howToPlayData.rules?.coreRules}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-tertiary/10 flex items-center justify-center text-lg">📏</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Core Rules</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.rules.coreRules}</p>
				</div>
			{/if}

			<!-- 11. Special Rules -->
			{#if howToPlayData.rules?.specialRules?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center text-lg">✨</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Special Rules</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.rules.specialRules as rule}
							<div>
								<p class="text-sm font-bold text-on-surface">{rule.name}</p>
								<p class="text-xs text-on-surface-variant leading-relaxed">{rule.description}</p>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 12. Edge Cases -->
			{#if howToPlayData.rules?.edgeCases}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-amber-400/10 flex items-center justify-center text-lg">⚠️</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Edge Cases</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.rules.edgeCases}</p>
				</div>
			{/if}

			<!-- 13. Variants -->
			{#if howToPlayData.variants?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center text-lg">🎲</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Variants</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.variants as variant}
							<div>
								<p class="text-sm font-bold text-on-surface">{variant.name}</p>
								<p class="text-xs text-on-surface-variant leading-relaxed">{variant.description}</p>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 14. Scoring -->
			{#if howToPlayData.scoring?.methods?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-amber-400/10 flex items-center justify-center text-lg">🏆</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Scoring</h3>
					</div>
					<div class="pl-12 space-y-1">
						{#each howToPlayData.scoring.methods as method}
							<div class="flex justify-between items-center text-sm py-1.5 border-b border-outline-variant/10 last:border-none">
								<span class="text-on-surface">{method.item}</span>
								<span class="font-bold text-primary text-xs">{method.points}</span>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- 15. How to Win -->
			{#if howToPlayData.winCondition?.details || howToPlayData.winCondition?.type}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-amber-400/10 flex items-center justify-center text-lg">🥇</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">How to Win</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12">
						{howToPlayData.winCondition.details ?? howToPlayData.winCondition.type}
					</p>
				</div>
			{/if}

			<!-- 16. End of Game -->
			{#if howToPlayData.endCondition?.trigger}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-tertiary/10 flex items-center justify-center text-lg">🏁</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">End of Game</h3>
					</div>
					<div class="pl-12 space-y-1">
						<p class="text-sm text-on-surface leading-relaxed">{howToPlayData.endCondition.trigger}</p>
						{#if howToPlayData.endCondition.notes}
							<p class="text-xs text-on-surface-variant leading-relaxed">{howToPlayData.endCondition.notes}</p>
						{/if}
					</div>
				</div>
			{/if}

			<!-- 17. Tips -->
			{#if howToPlayData.tips?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-secondary/10 flex items-center justify-center text-lg">💡</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Tips for New Players</h3>
					</div>
					<ul class="pl-12 space-y-2">
						{#each howToPlayData.tips as tip}
							<li class="flex items-start gap-2 text-sm text-on-surface leading-relaxed">
								<span class="material-symbols-outlined text-[14px] mt-0.5 text-secondary flex-shrink-0">check_circle</span>
								{tip}
							</li>
						{/each}
					</ul>
				</div>
			{/if}

			<!-- 18. FAQ -->
			{#if howToPlayData.faq?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-tertiary/10 flex items-center justify-center text-lg">❓</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">FAQ</h3>
					</div>
					<div class="space-y-2">
						{#each howToPlayData.faq as item, i}
							<div class="rounded-2xl border border-outline-variant/10 bg-surface-container-low/30 overflow-hidden">
								<button
									onclick={() => toggleFaq(i)}
									class="w-full flex items-center justify-between gap-3 p-4 text-left"
								>
									<span class="text-sm font-semibold text-on-surface leading-snug">{item.question}</span>
									<span class="material-symbols-outlined text-[18px] text-on-surface-variant flex-shrink-0 transition-transform duration-200 {expandedFaq.has(i) ? 'rotate-180' : ''}">
										expand_more
									</span>
								</button>
								{#if expandedFaq.has(i)}
									<div class="px-4 pb-4">
										<p class="text-sm text-on-surface-variant leading-relaxed">{item.answer}</p>
									</div>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- Raw fallback (if JSON parse failed on backend) -->
			{#if howToPlayData.raw}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-surface-container-high flex items-center justify-center text-lg">📄</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">Rules Summary</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.raw}</p>
				</div>
			{/if}

			<!-- Rulebook PDF Link -->
			{#if howToPlayRulebookUrl}
				<div class="pt-2">
					<a
						href={howToPlayRulebookUrl}
						target="_blank"
						rel="noopener noreferrer"
						class="flex items-center justify-center gap-2 w-full px-5 py-3 rounded-2xl bg-surface-container-high text-on-surface text-sm font-bold hover:bg-surface-container transition-colors"
					>
						<span class="material-symbols-outlined text-[18px] text-primary">picture_as_pdf</span>
						View Official Rulebook PDF
						<span class="material-symbols-outlined text-[14px] text-on-surface-variant">open_in_new</span>
					</a>
				</div>
			{/if}
		{:else if howToPlayState === "error"}
			<div
				class="rounded-2xl border border-outline-variant/10 bg-surface-container-low/20 p-5 text-center"
			>
				<p class="text-sm text-on-surface-variant">
					Could not load guide. Use the AI Assistant below for help.
				</p>
			</div>
		{/if}
	{:else if rulebookState === "error"}
		<p class="text-center text-xs text-error py-8">
			Failed to load rulebook status. Try refreshing.
		</p>
	{/if}

	<!-- Admin upload (always visible to admins) -->
	{#if isAdmin}
		<div
			class="rounded-2xl border border-outline-variant/10 bg-surface-container-low/20 p-4"
		>
			<p
				class="text-[10px] font-bold uppercase tracking-widest text-primary mb-3"
			>
				Admin
			</p>
			<input
				bind:this={adminFileInput}
				type="file"
				accept="application/pdf"
				class="hidden"
				onchange={handleAdminUpload}
			/>
			<button
				onclick={() => adminFileInput.click()}
				disabled={uploading}
				class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-primary/10 text-primary text-sm font-bold disabled:opacity-50"
			>
				{#if uploading}
					<span
						class="material-symbols-outlined text-[18px] animate-spin"
						>progress_activity</span
					>
					Uploading…
				{:else}
					<span class="material-symbols-outlined text-[18px]"
						>admin_panel_settings</span
					>
					Override: Upload PDF (auto-approve)
				{/if}
			</button>
		</div>
	{/if}

	<!-- AI Assistant CTA -->
	<!-- <button
		onclick={onOpenAssistant}
		class="w-full bg-tertiary-container/30 rounded-3xl p-6 border border-tertiary/10 flex flex-col items-center text-center gap-3 mt-4 hover:bg-tertiary-container/40 transition-colors"
	>
		<div class="w-12 h-12 rounded-full bg-tertiary/10 flex items-center justify-center text-tertiary">
			<span class="material-symbols-outlined">smart_toy</span>
		</div>
		<div class="space-y-1">
			<h4 class="font-bold text-on-tertiary-container">Still have questions?</h4>
			<p class="text-[11px] text-on-tertiary-container/70 leading-relaxed px-4">
				Our AI Assistant can answer specific edge cases and unusual situations.
			</p>
		</div>
	</button> -->
</div>

<style>
	.pl-13 {
		padding-left: 3.25rem;
	}
</style>
