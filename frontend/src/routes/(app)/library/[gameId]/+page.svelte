<script lang="ts">
	import type { PageData } from "./$types";
	import type { PlayLog, UserGame } from "$lib/types";
	import { gamesApi } from "$lib/api/games";
	import { toast } from "svelte-sonner";
	import HowToPlayTab from "$lib/components/game/HowToPlayTab.svelte";
	import AiAssistantDrawer from "$lib/components/game/AiAssistantDrawer.svelte";

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const game = $derived(data.game);
	let myEntry = $state<UserGame | null>(null);
	let activeTab = $state<"overview" | "details" | "mystats" | "howtoplay">("overview");
	let showAssistant = $state(false);
	let descExpanded = $state(false);
	let saving = $state(false);
	let savingNotes = $state(false);
	let notesValue = $state("");
	let playLogs = $state<PlayLog[]>([]);
	let loadingLogs = $state(false);

	$effect(() => {
		myEntry = data.myEntry;
		notesValue = data.myEntry?.notes ?? "";
	});

	$effect(() => {
		if (activeTab === "mystats") {
			loadingLogs = true;
			gamesApi
				.getPlays(game.id)
				.then((logs) => {
					playLogs = logs;
				})
				.catch(() => {})
				.finally(() => {
					loadingLogs = false;
				});
		}
	});

	function formatPlayDate(iso: string) {
		return new Date(iso).toLocaleDateString(undefined, {
			year: "numeric",
			month: "short",
			day: "numeric",
		});
	}

	async function toggle(flag: "isOwned" | "isFavorited") {
		saving = true;
		try {
			const current = myEntry ?? {
				isOwned: false,
				isFavorited: false,
			};
			myEntry = await gamesApi.updateCollection(game.id, {
				[flag]: !current[flag],
			});
		} catch {
			toast.error("Could not update collection");
		} finally {
			saving = false;
		}
	}

	async function remove() {
		if (!myEntry) return;
		saving = true;
		try {
			await gamesApi.removeFromCollection(game.id);
			myEntry = null;
			notesValue = "";
			toast.success("Removed from collection");
		} catch {
			toast.error("Could not remove");
		} finally {
			saving = false;
		}
	}

	async function logPlay() {
		try {
			myEntry = await gamesApi.logPlay(game.id);
			playLogs = await gamesApi.getPlays(game.id);
			toast.success("Play logged!");
		} catch {
			toast.error("Could not log play");
		}
	}

	async function setRating(rating: number) {
		try {
			myEntry = await gamesApi.updateCollection(game.id, {
				personalRating: rating,
			});
		} catch {
			toast.error("Could not save rating");
		}
	}

	async function saveNotes() {
		savingNotes = true;
		try {
			myEntry = await gamesApi.updateCollection(game.id, {
				notes: notesValue,
			});
		} catch {
			toast.error("Could not save notes");
		} finally {
			savingNotes = false;
		}
	}

	const flagLabel = {
		isOwned: { icon: "check_box", label: "Own" },
		isFavorited: { icon: "favorite", label: "Favorite" },
	} as const;

	function hasChips(arr: string[] | null | undefined) {
		return arr && arr.length > 0;
	}

	function decodeHtml(s: string): string {
		return s
			.replace(/&quot;/g, '"')
			.replace(/&#34;/g, '"')
			.replace(/&amp;/g, "&")
			.replace(/&lt;/g, "<")
			.replace(/&gt;/g, ">")
			.replace(/&#39;/g, "'")
			.replace(/&apos;/g, "'")
			.replace(/&ndash;/g, "–")
			.replace(/&mdash;/g, "—")
			.replace(/&nbsp;/g, " ");
	}
</script>

<svelte:head><title>{game.title} — Meeple & Hearth</title></svelte:head>

<!-- Hero cover image -->
{#if game.imageUrl || game.thumbnailUrl}
	<div class="relative -mx-4 mb-6">
		<img
			src={game.imageUrl ?? game.thumbnailUrl ?? ""}
			alt={game.title}
			class="w-full h-[320px] object-cover"
		/>
		<div
			class="absolute inset-0 bg-gradient-to-t from-background via-background/30 to-transparent"
		></div>
		<div class="absolute bottom-4 left-4 right-4">
			{#if game.families && game.families.length > 0}
				<span
					class="inline-block text-[10px] font-bold uppercase tracking-widest text-primary bg-primary/10 px-2 py-0.5 rounded-full mb-2"
					>{game.families[0]}</span
				>
			{/if}
			<h2
				class="text-2xl font-extrabold font-headline text-on-surface leading-tight"
			>
				{game.title}
			</h2>
			{#if game.designers && game.designers.length > 0}
				<p class="text-xs text-on-surface-variant mt-0.5">
					by {game.designers.slice(0, 2).join(", ")}
				</p>
			{/if}
		</div>
	</div>
{:else}
	<div class="mb-6 pt-2">
		<h2 class="text-2xl font-extrabold font-headline mb-1">{game.title}</h2>
		{#if game.designers && game.designers.length > 0}
			<p class="text-sm text-on-surface-variant">
				by {game.designers.slice(0, 2).join(", ")}
			</p>
		{/if}
	</div>
{/if}

<!-- Stats bar -->
<div class="grid grid-cols-3 gap-2 mb-5">
	{#each [{ label: "Players", value: game.minPlayers && game.maxPlayers ? `${game.minPlayers}–${game.maxPlayers}` : game.minPlayers ? `${game.minPlayers}+` : "—", icon: "group" }, { label: "Time", value: game.playTime ? `${game.playTime}m` : "—", icon: "timer" }, { label: "Complexity", value: game.complexityWeight ? game.complexityWeight.toFixed(1) : "—", icon: "psychology" }] as stat}
		<div class="bg-surface-container-low rounded-xl p-3 text-center">
			<span
				class="material-symbols-outlined text-on-surface-variant text-[16px]"
				>{stat.icon}</span
			>
			<p class="text-base font-extrabold font-headline mt-0.5">
				{stat.value}
			</p>
			<p
				class="text-[10px] font-bold uppercase tracking-widest text-on-surface-variant"
			>
				{stat.label}
			</p>
		</div>
	{/each}
</div>

<!-- BGG rating + year row -->
<div class="flex items-center gap-4 mb-5 px-1">
	{#if game.bggRating}
		<div class="flex items-center gap-1">
			<span
				class="material-symbols-outlined text-amber-400 text-[16px]"
				style="font-variation-settings: 'FILL' 1;">star</span
			>
			<span class="font-bold text-sm">{game.bggRating.toFixed(2)}</span>
			{#if game.usersRated}
				<span class="text-xs text-on-surface-variant"
					>({game.usersRated.toLocaleString()} ratings)</span
				>
			{/if}
		</div>
	{/if}
	{#if game.rank}
		<div class="flex items-center gap-1">
			<span class="material-symbols-outlined text-primary text-[14px]"
				>military_tech</span
			>
			<span class="text-xs font-bold text-on-surface-variant"
				>BGG #{game.rank}</span
			>
		</div>
	{/if}
	{#if game.yearPublished}
		<span class="text-xs text-on-surface-variant ml-auto"
			>{game.yearPublished}</span
		>
	{/if}
</div>

<!-- Collection action buttons + AI -->
<div class="flex gap-2 mb-2">
	{#each ["isFavorited", "isOwned"] as const as flag}
		<button
			onclick={() => toggle(flag)}
			disabled={saving}
			class="flex-1 flex flex-col items-center gap-1 py-3 rounded-xl transition-colors
				{myEntry?.[flag]
				? 'bg-primary text-on-primary'
				: 'bg-surface-container-high text-on-surface-variant'}
				disabled:opacity-50"
		>
			<span
				class="material-symbols-outlined text-[20px]"
				style={myEntry?.[flag]
					? "font-variation-settings: 'FILL' 1;"
					: ""}
			>
				{flagLabel[flag].icon}
			</span>
			<span class="text-xs font-bold">{flagLabel[flag].label}</span>
		</button>
	{/each}
	<button
		onclick={() => (showAssistant = true)}
		class="flex-1 flex flex-col items-center gap-1 py-3 rounded-xl transition-colors bg-tertiary-container text-on-tertiary-container"
	>
		<span class="material-symbols-outlined text-[20px]">smart_toy</span>
		<span class="text-xs font-bold">Ask AI</span>
	</button>
</div>

<!-- Tabs -->
<div class="mt-6 flex gap-6 border-b border-outline-variant/20 mb-4">
	{#each [{ id: "overview", label: "Overview" }, { id: "howtoplay", label: "How to Play" }, { id: "details", label: "Details" }, { id: "mystats", label: "My Stats" }] as tab}
		<button
			onclick={() =>
				(activeTab = tab.id as any)}
			class="relative pb-3 text-sm font-bold transition-colors {activeTab ===
			tab.id
				? 'text-primary'
				: 'text-on-surface-variant'}"
		>
			{tab.label}
			{#if activeTab === tab.id}
				<div
					class="absolute bottom-0 left-0 w-full h-0.5 bg-primary rounded-t-full"
				></div>
			{/if}
		</button>
	{/each}
</div>

<!-- Overview tab -->
{#if activeTab === "overview"}
	<!-- Description -->
	{#if game.description}
		<div class="mb-5">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				About
			</p>
			<p
				class="text-sm text-on-surface leading-relaxed {descExpanded
					? ''
					: 'line-clamp-4'}"
			>
				{decodeHtml(game.description!)}
			</p>
			<button
				onclick={() => (descExpanded = !descExpanded)}
				class="text-xs text-primary font-bold mt-1"
			>
				{descExpanded ? "Show less" : "Read more"}
			</button>
		</div>
	{/if}

	<!-- Categories -->
	{#if hasChips(game.categories)}
		<div class="mb-4 mt-2">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Categories
			</p>
			<div class="flex flex-wrap gap-2">
				{#each game.categories! as cat}
					<span
						class="text-xs font-medium bg-secondary-container text-on-secondary-container px-3 py-1 rounded-full"
						>{cat}</span
					>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Mechanics -->
	{#if hasChips(game.mechanics)}
		<div class="mb-4 mt-2">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Mechanics
			</p>
			<div class="flex flex-wrap gap-2">
				{#each game.mechanics! as mech}
					<span
						class="text-xs font-medium bg-surface-container-high text-on-surface px-3 py-1 rounded-full"
						>{mech}</span
					>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Honors / Awards -->
	{#if hasChips(game.honors)}
		<div class="mb-4 mt-2">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Awards
			</p>
			<div class="space-y-1">
				{#each game.honors! as honor}
					<div class="flex items-center gap-2">
						<span
							class="material-symbols-outlined text-amber-400 text-[14px]"
							style="font-variation-settings: 'FILL' 1;"
							>emoji_events</span
						>
						<span class="text-xs text-on-surface">{honor}</span>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- My Stats tab -->
{:else if activeTab === "mystats"}
	<!-- Play history timeline -->
	<div class="my-5">
		<p
			class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-3"
		>
			Play History ({myEntry?.playCount ?? 0})
		</p>
		{#if loadingLogs}
			<p class="text-sm text-on-surface-variant text-center py-4">
				Loading…
			</p>
		{:else if playLogs.length === 0}
			<p class="text-sm text-on-surface-variant text-center py-4">
				No plays logged yet.<br />Use the + button to log one.
			</p>
		{:else}
			<div class="relative pl-5">
				<div
					class="absolute left-1.5 top-0 bottom-0 w-px bg-outline-variant/30"
				></div>
				{#each playLogs as log, i}
					<div class="relative mb-3 last:mb-0">
						<div
							class="absolute -left-[14px] top-1 w-2.5 h-2.5 rounded-full bg-primary {i ===
							0
								? 'ring-2 ring-primary/30'
								: ''}"
						></div>
						<p class="text-sm font-medium text-on-surface">
							{formatPlayDate(log.playedAt)}
						</p>
						{#if i === 0}
							<p
								class="text-[10px] text-primary font-bold uppercase tracking-widest"
							>
								Latest
							</p>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Personal rating -->
	<div class="mb-4 mt-2">
		<p
			class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-3"
		>
			My Rating
		</p>
		<div class="flex gap-1.5">
			{#each Array.from({ length: 10 }, (_, i) => i + 1) as n}
				<button
					onclick={() =>
						setRating(myEntry?.personalRating === n ? 0 : n)}
					class="flex-1 flex flex-col items-center gap-0.5 py-2 rounded-lg transition-colors
						{(myEntry?.personalRating ?? 0) >= n
						? 'bg-amber-400/20 text-amber-400'
						: 'bg-surface-container-high text-on-surface-variant'}"
				>
					<span
						class="material-symbols-outlined text-[16px]"
						style={(myEntry?.personalRating ?? 0) >= n
							? "font-variation-settings: 'FILL' 1;"
							: ""}>star</span
					>
					<span class="text-[9px] font-bold">{n}</span>
				</button>
			{/each}
		</div>
		{#if myEntry?.personalRating}
			<p class="text-xs text-center text-on-surface-variant mt-2">
				Your rating: <span class="font-bold text-amber-400"
					>{myEntry.personalRating}/10</span
				>
			</p>
		{/if}
	</div>

	<!-- Notes -->
	<div class="mb-4 mt-2">
		<p
			class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
		>
			Notes
		</p>
		<textarea
			bind:value={notesValue}
			onblur={saveNotes}
			placeholder="Any thoughts, house rules, play tips…"
			rows="4"
			class="w-full bg-surface-container-low rounded-xl px-3 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 resize-none focus:outline-none focus:ring-1 focus:ring-primary"
		></textarea>
		{#if savingNotes}
			<p class="text-xs text-on-surface-variant mt-1">Saving…</p>
		{/if}
	</div>

	<!-- Community stat -->
	{#if game.ownedCount}
		<div class="flex items-center gap-2 text-xs text-on-surface-variant">
			<span class="material-symbols-outlined text-[14px]">group</span>
			<span>{game.ownedCount.toLocaleString()} BGG users own this</span>
		</div>
	{/if}

	<!-- Details tab -->
{:else if activeTab === "howtoplay"}
	<HowToPlayTab gameId={game.id} onOpenAssistant={() => (showAssistant = true)} />
{:else}
	<!-- Details tab -->
	<!-- Designers & Publishers -->
	{#if hasChips(game.designers)}
		<div class="mb-4">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Designers
			</p>
			<div class="flex flex-wrap gap-2">
				{#each game.designers! as d}
					<span
						class="text-xs font-medium bg-surface-container-high text-on-surface px-3 py-1 rounded-full"
						>{d}</span
					>
				{/each}
			</div>
		</div>
	{/if}

	{#if hasChips(game.publishers)}
		<div class="mb-4 mt-2">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Publishers
			</p>
			<div class="flex flex-wrap gap-2">
				{#each game.publishers!.slice(0, 5) as p}
					<span
						class="text-xs font-medium bg-surface-container-high text-on-surface px-3 py-1 rounded-full"
						>{p}</span
					>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Sub-domains -->
	{#if hasChips(game.families)}
		<div class="mb-4 mt-2">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Genre
			</p>
			<div class="flex flex-wrap gap-2">
				{#each game.families! as f}
					<span
						class="text-xs font-medium bg-tertiary-container text-on-tertiary-container px-3 py-1 rounded-full"
						>{f}</span
					>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Extra stats -->
	<div class="space-y-3 mb-4 mt-2">
		{#if game.minAge}
			<div class="flex justify-between text-sm">
				<span class="text-on-surface-variant font-medium">Min Age</span>
				<span class="font-bold">{game.minAge}+</span>
			</div>
		{/if}
		{#if game.gameType}
			<div class="flex justify-between text-sm">
				<span class="text-on-surface-variant font-medium">Type</span>
				<span class="font-bold capitalize">{game.gameType}</span>
			</div>
		{/if}
	</div>

	<!-- BGG link -->
	{#if game.bggUrl}
		<a
			href={game.bggUrl}
			target="_blank"
			rel="noopener noreferrer"
			class="flex items-center justify-center gap-2 w-full py-3 rounded-xl bg-surface-container-high text-on-surface text-sm font-bold"
		>
			<span class="material-symbols-outlined text-[18px]"
				>open_in_new</span
			>
			View on BoardGameGeek
		</a>
	{/if}
{/if}

<AiAssistantDrawer
	bind:show={showAssistant}
	gameId={game.id}
	gameTitle={game.title}
/>
