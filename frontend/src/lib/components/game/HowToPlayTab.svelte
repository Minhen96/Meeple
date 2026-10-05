<script lang="ts">
	import { onMount } from "svelte";
	import { SvelteSet } from "svelte/reactivity";
	import ProgressBar from "$lib/components/ui/ProgressBar.svelte";
	import { rulebookApi } from "$lib/api/rulebook";
	import { adminApi } from "$lib/api/admin";
	import { howToPlayApi } from "$lib/api/howtoplay";
	import { ruleNotesApi } from "$lib/api/ruleNotes";
	import { currentUser } from "$lib/stores/auth";
	import { subscribeToHowToPlayProgress } from "$lib/stores/websocket";
	import { toast } from "svelte-sonner";
	import { ApiRequestError } from "$lib/api/client";
	import { errorMessage, m } from "$lib/i18n";
	import { formatPercent } from "$lib/i18n/format";
	import type {
		HowToPlayApiResponse,
		HowToPlayContent,
		RuleNote,
		MyRuleNote
	} from "$lib/types";

	interface Props {
		gameId: string;
	}
	let { gameId }: Props = $props();

	const isAdmin = $derived($currentUser?.isAdmin ?? false);

	type RulebookState =
		| "loading"
		| "no_rulebook"
		| "generating"
		| "pending_review"
		| "ready"
		| "error";
	let rulebookState: RulebookState = $state("loading");
	let uploading: boolean = $state(false);
	let myQueuePosition: number | null = $state(null);

	// How-to-play content
	type HowToPlayState = "idle" | "loading" | "generating" | "ready" | "failed" | "error";
	let howToPlayState: HowToPlayState = $state("idle");
	let howToPlayData: HowToPlayContent | null = $state(null);
	let howToPlaySourceMode: string | null = $state(null);
	let howToPlayDisclaimer: string | null = $state(null);
	let howToPlayRulebookUrl: string | null = $state(null);
	let howToPlayProgress: number = $state(0);
	let howToPlayErrorMessage: string | null = $state(null);
	let rulebookPollInterval: ReturnType<typeof setInterval> | null = null;
	let unsubscribeHtp: (() => void) | null = null;

	// FAQ expand state
	const expandedFaq = new SvelteSet<number>();

	// File input refs
	let fileInput: HTMLInputElement = $state() as HTMLInputElement;
	let adminFileInput: HTMLInputElement = $state() as HTMLInputElement;

	// Rule notes state
	let approvedNotes: RuleNote[] = $state([]);
	let myNote: MyRuleNote | null = $state(null);
	let noteText = $state('');
	let showNoteEditor = $state(false);
	let submittingNote = $state(false);
	let deletingNote = $state(false);

	const HTP_POLL_MS = 5000;
	/**
	 * Safety net: if the backend still reports "not_generated" this long after we
	 * started tracking a generation, assume the job was lost and offer a retry.
	 */
	const HTP_NOT_GENERATED_TIMEOUT_MS = 2 * 60 * 1000;
	const htpFailedFallback = () => m("library.htp.failedFallback");

	let destroyed = false;
	let htpPollInterval: ReturnType<typeof setInterval> | null = null;
	// True while POST /generate is in flight: until the backend has accepted the
	// new job, a REST "failed" status may still describe the previous attempt.
	let htpGenerateRequestPending = false;
	// Bumped on every start/stop so late async callbacks from an older run are ignored.
	let htpGeneration = 0;

	onMount(() => {
		initRulebookStatus();
		return () => {
			destroyed = true;
			stopRulebookPolling();
			stopHtpTracking();
		};
	});

	function friendlyError(err: unknown, fallback: string): string {
		if (err instanceof ApiRequestError) {
			if (err.status === 429) return errorMessage("RATE_LIMITED");
			if (err.status === 0) return errorMessage(err.code);
		}
		return fallback;
	}

	async function initRulebookStatus() {
		try {
			const status = await rulebookApi.getStatus(gameId);
			if (destroyed) return;
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
				howToPlayState = "loading";
				fetchHowToPlay();
			}
		} catch {
			if (!destroyed) rulebookState = "error";
		}
	}

	async function fetchHowToPlay() {
		howToPlayState = "loading";
		try {
			const res = await howToPlayApi.get(gameId);
			if (destroyed) return;
			if (res.status === "ready" && res.data) {
				applyHowToPlayReady(res);
			} else if (res.status === "generating") {
				howToPlayState = "generating";
				howToPlayProgress = res.progress ?? 0;
				startHtpTracking();
			} else if (res.status === "failed") {
				showHtpFailed(res.errorMessage);
			} else {
				// not_generated
				howToPlayState = "idle";
			}
		} catch {
			if (!destroyed) howToPlayState = "error";
		}
	}

	function applyHowToPlayReady(res: HowToPlayApiResponse) {
		howToPlayState = "ready";
		howToPlayData = res.data;
		howToPlaySourceMode = res.sourceMode;
		howToPlayDisclaimer = res.disclaimer;
		howToPlayRulebookUrl = res.rulebookUrl;
		approvedNotes = res.approvedNotes ?? [];
		fetchMyNote();
	}

	function stopHtpTracking() {
		htpGeneration++;
		unsubscribeHtp?.();
		unsubscribeHtp = null;
		if (htpPollInterval !== null) clearInterval(htpPollInterval);
		htpPollInterval = null;
	}

	function showHtpFailed(message: string | null | undefined) {
		howToPlayErrorMessage = message?.trim() ? message : htpFailedFallback();
		howToPlayState = "failed";
	}

	/** Terminal generation failure: stop polling, unsubscribe, offer a retry. */
	function failHtp(message?: string | null) {
		stopHtpTracking();
		showHtpFailed(message);
	}

	async function loadReadyHtp(generation: number) {
		try {
			const res = await howToPlayApi.get(gameId);
			if (destroyed || generation !== htpGeneration) return;
			if (res.status === "ready" && res.data) {
				stopHtpTracking();
				applyHowToPlayReady(res);
			} else if (res.status === "failed") {
				failHtp(res.errorMessage);
			}
		} catch {
			if (!destroyed && generation === htpGeneration) failHtp();
		}
	}

	/**
	 * Track generation progress over WebSocket, with a REST polling fallback
	 * for when the socket is down or a message is missed. Call BEFORE
	 * triggering generation so no progress/ready message can be lost.
	 */
	function startHtpTracking() {
		stopHtpTracking();
		if (destroyed) return;
		const generation = htpGeneration;

		unsubscribeHtp = subscribeToHowToPlayProgress(gameId, (msg) => {
			if (generation !== htpGeneration) return;
			if (msg.status === "generating") {
				howToPlayProgress = Math.max(howToPlayProgress, msg.progress);
			} else if (msg.status === "ready") {
				void loadReadyHtp(generation);
			} else if (msg.status === "failed" || msg.status === "error") {
				failHtp(msg.errorMessage);
			}
		});

		const startedAt = Date.now();
		htpPollInterval = setInterval(async () => {
			try {
				const res = await howToPlayApi.get(gameId);
				if (destroyed || generation !== htpGeneration) return;
				if (res.status === "ready" && res.data) {
					stopHtpTracking();
					applyHowToPlayReady(res);
				} else if (res.status === "failed") {
					if (!htpGenerateRequestPending) failHtp(res.errorMessage);
				} else if (res.status === "generating") {
					if (res.progress !== null) {
						howToPlayProgress = Math.max(howToPlayProgress, res.progress);
					}
				} else if (
					res.status === "not_generated" &&
					Date.now() - startedAt > HTP_NOT_GENERATED_TIMEOUT_MS
				) {
					failHtp();
				}
			} catch {
				// transient (network / rate limit) — keep polling
			}
		}, HTP_POLL_MS);
	}

	async function handleGenerateHowToPlay() {
		howToPlayState = "generating";
		howToPlayProgress = 0;
		howToPlayErrorMessage = null;
		// Subscribe first so a fast "ready" message can't be missed.
		startHtpTracking();
		htpGenerateRequestPending = true;
		try {
			const res = await howToPlayApi.generate(gameId);
			htpGenerateRequestPending = false;
			if (destroyed) return;
			if (res?.status === "ready" && res.data) {
				stopHtpTracking();
				applyHowToPlayReady(res);
			} else if (res?.status === "failed") {
				failHtp(res.errorMessage);
			}
		} catch (err) {
			htpGenerateRequestPending = false;
			stopHtpTracking();
			if (destroyed) return;
			if (err instanceof ApiRequestError && err.status === 429) {
				howToPlayState = "idle";
			} else {
				howToPlayState = "error";
			}
			toast.error(friendlyError(err, m("library.htp.generateFailed")));
		}
	}

	function stopRulebookPolling() {
		if (rulebookPollInterval !== null) clearInterval(rulebookPollInterval);
		rulebookPollInterval = null;
	}

	function startRulebookPolling() {
		if (rulebookPollInterval !== null || destroyed) return;
		rulebookPollInterval = setInterval(async () => {
			try {
				const status = await rulebookApi.getStatus(gameId);
				if (destroyed || rulebookPollInterval === null) return;
				if (status.hasRulebook) {
					stopRulebookPolling();
					rulebookState = "ready";
					fetchHowToPlay();
				}
			} catch {
				if (destroyed) return;
				stopRulebookPolling();
				rulebookState = "error";
			}
		}, 3000);
	}

	async function handleUserUpload(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;
		uploading = true;
		try {
			const result = await rulebookApi.upload(gameId, file);
			if (result.status === "pending_review") {
				// User uploads must be approved by an admin before they go live.
				rulebookState = "pending_review";
				myQueuePosition = result.queuePosition ?? null;
				toast.success(m("library.htp.uploadSubmitted"));
			} else if (result.status === "ingesting") {
				rulebookState = "generating";
				toast.success(m("library.htp.uploadProcessing"));
				startRulebookPolling();
			} else if (result.status === "already_done") {
				rulebookState = "ready";
				fetchHowToPlay();
			}
		} catch (err) {
			toast.error(friendlyError(err, m("library.htp.uploadFailed")));
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
			toast.success(m("admin.upload.started"));
			startRulebookPolling();
		} catch (err) {
			const detail =
				err instanceof ApiRequestError && err.status !== 429 && err.message
					? ` ${err.message}`
					: "";
			toast.error(friendlyError(err, `${m("admin.upload.failed")}${detail}`));
		} finally {
			uploading = false;
			adminFileInput.value = "";
		}
	}

	async function fetchMyNote() {
		try {
			myNote = await ruleNotesApi.getMy(gameId);
		} catch {
			// silently ignore — user may not be logged in
		}
	}

	async function submitNote() {
		if (!noteText.trim()) return;
		submittingNote = true;
		try {
			myNote = await ruleNotesApi.submit(gameId, noteText.trim());
			showNoteEditor = false;
			noteText = '';
			toast.success(m('library.htp.note.submitted'));
		} catch {
			toast.error(m('library.htp.note.submitFailed'));
		} finally {
			submittingNote = false;
		}
	}

	async function deleteNote() {
		deletingNote = true;
		try {
			await ruleNotesApi.deleteMy(gameId);
			myNote = null;
			noteText = '';
			showNoteEditor = false;
			toast.success(m('library.htp.note.removed'));
		} catch {
			toast.error(m('library.htp.note.removeFailed'));
		} finally {
			deletingNote = false;
		}
	}

	function toggleFaq(i: number) {
		if (expandedFaq.has(i)) expandedFaq.delete(i);
		else expandedFaq.add(i);
	}
</script>

<div class="py-4 space-y-8 pb-12">
	<!-- Hero Header -->
	<div
		class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-primary/10 via-background to-secondary/5 p-6"
	>
		<div class="relative z-10 flex items-start justify-between">
			<div class="space-y-1">
				<div
					class="flex items-center gap-2 text-primary font-black uppercase tracking-widest text-[10px]"
				>
					<span class="material-symbols-outlined text-[16px]"
						>auto_awesome</span
					>
					{m("library.htp.eyebrow")}
				</div>
				<h2 class="text-xl font-extrabold text-on-surface">
					{m("library.detail.tab.howToPlay")}
				</h2>
				<p
					class="text-xs text-on-surface-variant max-w-[240px] leading-relaxed"
				>
					{m("library.htp.subtitle")}
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
			{#each [1, 2, 3] as n (n)}
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
	{:else if rulebookState === "no_rulebook" && howToPlayState === "idle"}
		<div
			class="rounded-3xl bg-surface-container-low p-8 flex flex-col items-center text-center gap-4"
		>
			<div
				class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary/60"
			>
				<span class="material-symbols-outlined text-[36px]">auto_awesome</span>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">{m("library.htp.generateTitle")}</h3>
				<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
					{m("library.htp.generateBody")}
				</p>
			</div>
			<button
				onclick={handleGenerateHowToPlay}
				class="flex items-center justify-center gap-2 px-6 py-2.5 rounded-2xl bg-primary text-on-primary text-sm font-bold"
			>
				<span class="material-symbols-outlined text-[18px]">auto_awesome</span>
				{m("library.htp.generate")}
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
					disabled={uploading}
					class="w-full flex items-center justify-center gap-2 px-5 py-2.5 rounded-2xl bg-surface-container-high text-on-surface text-sm font-bold disabled:opacity-50 transition-opacity"
				>
					{#if uploading}
						<span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
						{m("library.htp.uploading")}
					{:else}
						<span class="material-symbols-outlined text-[18px]">upload_file</span>
						{m("library.htp.uploadPdf")}
					{/if}
				</button>
				<p class="text-[10px] text-on-surface-variant text-center mt-1.5">
					{m("library.htp.uploadHint")}
				</p>
			</div>
		</div>
	{:else if rulebookState === "generating"}
		<div
			class="rounded-3xl bg-primary/10 p-8 flex flex-col items-center text-center gap-4"
		>
			<div
				class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary"
			>
				<span class="material-symbols-outlined text-[36px] animate-spin"
					>progress_activity</span
				>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">{m("library.htp.processingTitle")}</h3>
				<p
					class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
				>
					{m("library.htp.processingBody")}
				</p>
			</div>
		</div>
	{:else if rulebookState === "pending_review"}
		<div
			class="rounded-3xl bg-secondary/10 p-8 flex flex-col items-center text-center gap-4"
		>
			<div
				class="w-16 h-16 rounded-2xl bg-secondary/10 flex items-center justify-center text-secondary"
			>
				<span class="material-symbols-outlined text-[36px]"
					>hourglass_top</span
				>
			</div>
			<div class="space-y-1">
				<h3 class="font-bold text-on-surface">{m("library.htp.reviewTitle")}</h3>
				<p
					class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
				>
					{myQueuePosition !== null
						? m("library.htp.reviewBodyPosition", { position: myQueuePosition + 1 })
						: m("library.htp.reviewBody")}
				</p>
			</div>
		</div>
	{:else}
		<!-- How-to-Play content (shown for both ready and no_rulebook states while HTP is active) -->
		{#if howToPlayState === "idle"}
			<!-- Rulebook exists but guide not yet requested -->
			<div
				class="rounded-3xl bg-surface-container-low p-8 flex flex-col items-center text-center gap-4"
			>
				<div
					class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center text-primary/60"
				>
					<span class="material-symbols-outlined text-[36px]">auto_awesome</span>
				</div>
				<div class="space-y-1">
					<h3 class="font-bold text-on-surface">{m("library.htp.generateTitle")}</h3>
					<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
						{m("library.htp.generateBody")}
					</p>
				</div>
				<button
					onclick={handleGenerateHowToPlay}
					class="flex items-center justify-center gap-2 px-6 py-2.5 rounded-2xl bg-primary text-on-primary text-sm font-bold"
				>
					<span class="material-symbols-outlined text-[18px]">auto_awesome</span>
					{m("library.htp.generate")}
				</button>
			</div>
		{:else if howToPlayState === "loading"}
			<div class="space-y-5">
				{#each [1, 2, 3] as n (n)}
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
				class="rounded-3xl bg-tertiary/10 p-8 flex flex-col items-center text-center gap-5"
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
						{m("library.htp.generatingTitle")}
					</h3>
					<p
						class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]"
					>
						{m("library.htp.generatingBody")}
					</p>
				</div>
				<div class="w-full max-w-[240px] space-y-1.5">
					<ProgressBar value={howToPlayProgress} tone="tertiary" label={m("library.htp.progressLabel")} />
					<p class="text-[11px] font-bold text-tertiary text-right">
						{formatPercent(howToPlayProgress)}
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
						{howToPlaySourceMode === "rulebook" ? m("library.htp.source.rulebook") : m("library.htp.source.ai")}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.overview")}</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12">
						{howToPlayData.overview ?? howToPlayData.objective}
					</p>
					{#if howToPlayData.overview && howToPlayData.objective}
						<p class="text-sm text-on-surface leading-relaxed pl-12 pt-1">
							<strong>{m("library.htp.goal")}</strong> {howToPlayData.objective}
						</p>
					{/if}
				</div>
			{/if}

			<!-- 2. What's in the Box -->
			{#if howToPlayData.components?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-surface-container-high flex items-center justify-center text-lg">📦</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.components")}</h3>
					</div>
					<div class="pl-12 flex flex-wrap gap-2">
						{#each howToPlayData.components as comp, i (i)}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.setup")}</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.setup}</p>
				</div>
			{/if}

			<!-- 4. Resources -->
			{#if howToPlayData.resources?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-amber-400/10 flex items-center justify-center text-lg">💰</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.resources")}</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.resources as resource, i (i)}
							<div>
								<p class="text-sm font-bold text-on-surface">{resource.name}</p>
								{#if resource.usedFor}
									<p class="text-xs text-on-surface-variant leading-relaxed">{m("library.htp.usedFor", { text: resource.usedFor })}</p>
								{/if}
								{#if resource.gainedBy}
									<p class="text-xs text-on-surface-variant leading-relaxed">{m("library.htp.gainedBy", { text: resource.gainedBy })}</p>
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.cards")}</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#if howToPlayData.cardSystem.deckRules}
							<p class="text-xs text-on-surface-variant leading-relaxed"><strong>{m("library.htp.deck")}</strong> {howToPlayData.cardSystem.deckRules}</p>
						{/if}
						{#if howToPlayData.cardSystem.handRules}
							<p class="text-xs text-on-surface-variant leading-relaxed"><strong>{m("library.htp.hand")}</strong> {howToPlayData.cardSystem.handRules}</p>
						{/if}
						{#if howToPlayData.cardSystem.cardTypes?.length}
							<div class="space-y-2">
								{#each howToPlayData.cardSystem.cardTypes as ct, i (i)}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.board")}</h3>
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.roles")}</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.roles.list as role, i (i)}
							<div>
								<p class="text-sm font-bold text-on-surface">{role.name}</p>
								<p class="text-xs text-on-surface-variant leading-relaxed">{role.abilities}</p>
								{#if role.winCondition}
									<p class="text-xs text-on-surface-variant leading-relaxed mt-0.5">{m("library.htp.win", { text: role.winCondition })}</p>
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.actions")}</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.actions as action, i (i)}
							<div>
								<p class="text-sm font-bold text-on-surface">{action.name}{#if action.type}<span class="text-xs font-normal text-on-surface-variant"> · {action.type}</span>{/if}</p>
								{#if action.cost}
									<p class="text-xs text-on-surface-variant leading-relaxed">{m("library.htp.cost", { text: action.cost })}</p>
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.flow")}</h3>
					</div>
					<div class="pl-12 space-y-4">
						{#if howToPlayData.gameStructure.turnOrder}
							<p class="text-xs text-on-surface-variant leading-relaxed">{howToPlayData.gameStructure.turnOrder}</p>
						{/if}
						{#each howToPlayData.gameStructure.phases as phase, i (i)}
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
										{#each phase.actions as action, j (j)}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.coreRules")}</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.rules.coreRules}</p>
				</div>
			{/if}

			<!-- 11. Special Rules -->
			{#if howToPlayData.rules?.specialRules?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center text-lg">✨</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.specialRules")}</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.rules.specialRules as rule, i (i)}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.edgeCases")}</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.rules.edgeCases}</p>
				</div>
			{/if}

			<!-- 13. Variants -->
			{#if howToPlayData.variants?.length}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center text-lg">🎲</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.variants")}</h3>
					</div>
					<div class="pl-12 space-y-3">
						{#each howToPlayData.variants as variant, i (i)}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.scoring")}</h3>
					</div>
					<div class="pl-12 space-y-1">
						{#each howToPlayData.scoring.methods as method, i (i)}
							<div class="flex justify-between items-center text-sm py-1.5 px-2 rounded-lg even:bg-surface-container-low">
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.win")}</h3>
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.end")}</h3>
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.tips")}</h3>
					</div>
					<ul class="pl-12 space-y-2">
						{#each howToPlayData.tips as tip, i (i)}
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.faq")}</h3>
					</div>
					<div class="space-y-2">
						{#each howToPlayData.faq as item, i (i)}
							<div class="rounded-2xl bg-surface-container-low overflow-hidden">
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
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.summary")}</h3>
					</div>
					<p class="text-sm text-on-surface leading-relaxed pl-12 whitespace-pre-line">{howToPlayData.raw}</p>
				</div>
			{/if}

			<!-- Community Notes -->
			{#if approvedNotes.length > 0}
				<div class="space-y-3">
					<div class="flex items-center gap-2.5">
						<div class="w-9 h-9 rounded-xl bg-secondary/10 flex items-center justify-center text-lg">📝</div>
						<h3 class="font-extrabold text-sm text-on-surface uppercase tracking-wide">{m("library.htp.section.notes")}</h3>
					</div>
					<div class="space-y-3 pl-12">
						{#each approvedNotes as note (note.id)}
							<div class="rounded-xl bg-surface-container-low p-3 space-y-1.5">
								<p class="text-sm text-on-surface leading-relaxed whitespace-pre-line">{note.content}</p>
								<p class="text-[10px] text-on-surface-variant">{m("library.htp.note.by", { username: note.submittedByUsername })}</p>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- Add Rule Note (logged-in users) -->
			{#if $currentUser}
				<div class="rounded-2xl bg-surface-container-low p-4 space-y-3">
					<p class="text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">{m("library.htp.note.mine")}</p>

					{#if myNote && !showNoteEditor}
						<div class="space-y-2">
							<p class="text-sm text-on-surface leading-relaxed whitespace-pre-line">{myNote.content}</p>
							<div class="flex items-center gap-2 flex-wrap">
								<span class="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full
									{myNote.status === 'approved' ? 'bg-primary/10 text-primary' :
									 myNote.status === 'rejected' ? 'bg-error/10 text-error' :
									 'bg-surface-container-high text-on-surface-variant'}">
									{myNote.status === 'pending' ? m('library.htp.note.pending') :
									 myNote.status === 'approved' ? m('library.htp.note.approved') : m('library.htp.note.rejected')}
								</span>
								{#if myNote.status === 'pending' || myNote.status === 'rejected'}
									<button
										onclick={() => { showNoteEditor = true; noteText = myNote!.content; }}
										class="text-xs text-primary font-bold"
									>{myNote.status === 'rejected' ? m('library.htp.note.resubmit') : m('library.htp.note.edit')}</button>
									<button
										onclick={deleteNote}
										disabled={deletingNote}
										class="text-xs text-error font-bold disabled:opacity-50"
									>{deletingNote ? m('library.htp.note.removing') : m('library.htp.note.remove')}</button>
								{/if}
							</div>
							{#if myNote.status === 'rejected' && myNote.rejectReason}
								<p class="text-xs text-error/80 italic">{m('library.htp.note.reason', { reason: myNote.rejectReason })}</p>
							{/if}
						</div>
					{:else if showNoteEditor}
						<textarea
							bind:value={noteText}
							placeholder={m('library.htp.note.placeholder')}
							rows="5"
							class="w-full bg-surface-container-low rounded-xl px-3 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 resize-none focus:outline-none focus:ring-1 focus:ring-primary"
						></textarea>
						<p class="text-[10px] text-on-surface-variant">{m('library.htp.note.reviewHint')}</p>
						<div class="flex gap-2">
							<button
								onclick={() => { showNoteEditor = false; noteText = ''; }}
								class="flex-1 py-2.5 rounded-xl bg-surface-container-high text-on-surface text-sm font-bold"
							>{m('common.cancel')}</button>
							<button
								onclick={submitNote}
								disabled={submittingNote || !noteText.trim()}
								class="flex-1 py-2.5 rounded-xl bg-primary text-on-primary text-sm font-bold disabled:opacity-50"
							>{submittingNote ? m('library.htp.note.submitting') : m('library.htp.note.submit')}</button>
						</div>
					{:else}
						<button
							onclick={() => { showNoteEditor = true; }}
							class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-surface-container-high text-on-surface-variant text-sm font-medium hover:text-on-surface transition-colors"
						>
							<span class="material-symbols-outlined text-[16px]">add</span>
							{m('library.htp.note.add')}
						</button>
					{/if}
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
						{m('library.htp.viewPdf')}
						<span class="material-symbols-outlined text-[14px] text-on-surface-variant">open_in_new</span>
					</a>
				</div>
			{/if}
		{:else if howToPlayState === "failed"}
			<div
				class="rounded-3xl bg-surface-container-low p-8 flex flex-col items-center text-center gap-4"
				role="alert"
			>
				<div
					class="w-16 h-16 rounded-2xl bg-error/10 flex items-center justify-center text-error"
				>
					<span class="material-symbols-outlined text-[36px]">error</span>
				</div>
				<div class="space-y-1">
					<h3 class="font-bold text-on-surface">{m('library.htp.failedTitle')}</h3>
					<p class="text-xs text-on-surface-variant leading-relaxed max-w-[240px]">
						{howToPlayErrorMessage ?? htpFailedFallback()}
					</p>
				</div>
				<button
					onclick={handleGenerateHowToPlay}
					class="flex items-center justify-center gap-2 px-6 py-2.5 rounded-2xl bg-primary text-on-primary text-sm font-bold"
				>
					<span class="material-symbols-outlined text-[18px]">refresh</span>
					{m('common.retry')}
				</button>
			</div>
		{:else if howToPlayState === "error"}
			<div
				class="rounded-2xl bg-surface-container-low p-5 flex flex-col items-center text-center gap-3"
				role="alert"
			>
				<p class="text-sm text-on-surface-variant">
					{m('library.htp.loadFailed')}
				</p>
				<!-- Reload the guide status: shows the guide, progress, or the Generate button. -->
				<button
					onclick={fetchHowToPlay}
					class="flex items-center justify-center gap-2 px-5 py-2 rounded-2xl bg-primary text-on-primary text-sm font-bold"
				>
					<span class="material-symbols-outlined text-[18px]">refresh</span>
					{m('common.retry')}
				</button>
			</div>
		{/if}
	{/if}
	{#if rulebookState === "error"}
		<p class="text-center text-xs text-error py-8">
			{m('library.htp.statusFailed')}
		</p>
	{/if}

	<!-- Admin upload (always visible to admins) -->
	{#if isAdmin}
		<div
			class="rounded-2xl bg-surface-container-low p-4"
		>
			<p
				class="text-[10px] font-bold uppercase tracking-widest text-primary mb-3"
			>
				{m('admin.label')}
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
					{m("library.htp.uploading")}
				{:else}
					<span class="material-symbols-outlined text-[18px]"
						>admin_panel_settings</span
					>
					{m('admin.upload.override')}
				{/if}
			</button>
		</div>
	{/if}

</div>

<style>
	.pl-13 {
		padding-left: 3.25rem;
	}
</style>
