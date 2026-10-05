<script lang="ts">
	import type { PageData } from "./$types";
	import type { GameFriend, GameReview, PlayLog, Post, UserGame } from "$lib/types";
	import { gamesApi, type UpdateCollectionPayload } from "$lib/api/games";
	import { toast } from "svelte-sonner";
	import HowToPlayTab from "$lib/components/game/HowToPlayTab.svelte";
	import AiAssistantDrawer from "$lib/components/game/AiAssistantDrawer.svelte";
	import StarRating from "$lib/components/game/StarRating.svelte";
	import Avatar from "$lib/components/ui/Avatar.svelte";
	import Skeleton from "$lib/components/ui/Skeleton.svelte";
	import { m, type MessageKey } from "$lib/i18n";

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const game = $derived(data.game);
	let myEntry = $state<UserGame | null>(null);
	type DetailTab = "overview" | "howtoplay" | "reviews" | "sessions" | "friends";
	let activeTab = $state<DetailTab>("overview");
	const detailTabs: { id: DetailTab; label: MessageKey }[] = [
		{ id: "overview", label: "library.detail.tab.overview" },
		{ id: "howtoplay", label: "library.detail.tab.howToPlay" },
		{ id: "reviews", label: "library.detail.tab.reviews" },
		{ id: "sessions", label: "library.detail.tab.sessions" },
		{ id: "friends", label: "library.detail.tab.friends" },
	];
	let showAssistant = $state(false);
	let descExpanded = $state(false);
	let saving = $state(false);
	let savingNotes = $state(false);
	let notesValue = $state("");
	let playLogs = $state<PlayLog[]>([]);
	let loadingLogs = $state(false);

	// Friend tabs load on first open
	let reviews = $state<GameReview[] | null>(null);
	let friends = $state<GameFriend[] | null>(null);
	let sessions = $state<Post[] | null>(null);
	let sessionsCursor = $state<string | null>(null);
	let sessionsHasMore = $state(false);
	let tabLoading = $state(false);
	let tabError = $state(false);

	$effect(() => {
		myEntry = data.myEntry;
		notesValue = data.myEntry?.notes ?? "";
		reviews = null;
		friends = null;
		sessions = null;
		sessionsCursor = null;
	});

	$effect(() => {
		const gameId = game.id;
		loadingLogs = true;
		gamesApi
			.getPlays(gameId)
			.then((logs) => (playLogs = logs))
			.catch(() => (playLogs = []))
			.finally(() => (loadingLogs = false));
	});

	$effect(() => {
		const tab = activeTab;
		if (tab === "reviews" && reviews === null) void loadTab(async () => (reviews = await gamesApi.getGameReviews(game.id)));
		if (tab === "friends" && friends === null) void loadTab(async () => (friends = await gamesApi.getGameFriends(game.id)));
		if (tab === "sessions" && sessions === null) void loadTab(() => loadSessions(true));
	});

	async function loadTab(load: () => Promise<unknown>) {
		tabLoading = true;
		tabError = false;
		try {
			await load();
		} catch {
			tabError = true;
		} finally {
			tabLoading = false;
		}
	}

	function retryTab() {
		if (activeTab === "reviews") reviews = null;
		if (activeTab === "friends") friends = null;
		if (activeTab === "sessions") sessions = null;
		tabError = false;
	}

	async function loadSessions(reset: boolean) {
		const result = await gamesApi.getGameSessions(game.id, reset ? null : sessionsCursor);
		const seen = new Set((reset ? [] : (sessions ?? [])).map((p) => p.id));
		sessions = [...(reset ? [] : (sessions ?? [])), ...result.items.filter((p) => !seen.has(p.id))];
		sessionsCursor = result.nextCursor;
		sessionsHasMore = result.hasMore;
	}

	let loadingMoreSessions = $state(false);
	async function moreSessions() {
		loadingMoreSessions = true;
		try {
			await loadSessions(false);
		} catch {
			toast.error(m("library.detail.loadFailed"));
		} finally {
			loadingMoreSessions = false;
		}
	}

	function formatPlayDate(iso: string) {
		return new Date(iso).toLocaleDateString(undefined, {
			year: "numeric",
			month: "short",
			day: "numeric",
		});
	}

	async function update(payload: UpdateCollectionPayload, failKey: MessageKey) {
		saving = true;
		try {
			const updated = await gamesApi.updateCollection(game.id, payload);
			myEntry = updated.id === null ? null : updated;
		} catch {
			toast.error(m(failKey));
		} finally {
			saving = false;
		}
	}

	function toggle(flag: "isOwned" | "isWishlisted" | "isFavorited") {
		void update({ [flag]: !(myEntry?.[flag] ?? false) }, "library.collection.saveFailed");
	}

	function setRating(rating: number) {
		void update({ personalRating: rating }, "library.rating.saveFailed");
	}

	async function saveNotes() {
		if ((myEntry?.notes ?? "") === notesValue.trim()) return;
		savingNotes = true;
		try {
			const updated = await gamesApi.updateCollection(game.id, { notes: notesValue });
			myEntry = updated.id === null ? null : updated;
		} catch {
			toast.error(m("library.mine.notesFailed"));
		} finally {
			savingNotes = false;
		}
	}

	async function deletePlay(play: PlayLog) {
		try {
			await gamesApi.deletePlay(play.id);
			playLogs = playLogs.filter((p) => p.id !== play.id);
			if (myEntry) myEntry = { ...myEntry, playCount: Math.max(0, myEntry.playCount - 1) };
			toast.success(m("library.mine.playDeleted"));
		} catch {
			toast.error(m("library.mine.deleteFailed"));
		}
	}

	const actions: {
		flag: "isOwned" | "isWishlisted" | "isFavorited";
		icon: string;
		off: MessageKey;
		on: MessageKey;
	}[] = [
		{ flag: "isOwned", icon: "check_box", off: "library.action.own", on: "library.action.inCollection" },
		{ flag: "isWishlisted", icon: "bookmark", off: "library.action.wishlist", on: "library.action.onWishlist" },
		{ flag: "isFavorited", icon: "favorite", off: "library.action.favorite", on: "library.action.favorited" },
	];

	function playsLabel(count: number) {
		return count === 1 ? m("library.plays.one") : m("library.plays.count", { count });
	}

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

<svelte:head><title>{game.title} — Meeple</title></svelte:head>

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
			{@render ownedByFriends()}
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
		{@render ownedByFriends()}
	</div>
{/if}

{#snippet ownedByFriends()}
	{#if game.ownedByFriends.length > 0}
		<button
			type="button"
			onclick={() => (activeTab = "friends")}
			class="mt-2 flex items-center gap-2"
		>
			<span class="flex -space-x-2">
				{#each game.ownedByFriends as friend (friend.id)}
					<Avatar
						src={friend.avatarUrl}
						name={friend.displayName ?? friend.username}
						size="xs"
						className="ring-2 ring-background"
					/>
				{/each}
			</span>
			<span class="text-xs font-bold text-on-surface">
				{game.ownedByFriends.length === 1
					? m("library.detail.ownedByOneFriend")
					: m("library.detail.ownedByFriends", { count: game.ownedByFriends.length })}
			</span>
		</button>
	{/if}
{/snippet}

<!-- Stats bar -->
<div class="grid grid-cols-3 gap-2 mb-5">
	{#each [{ label: "Players", value: game.minPlayers && game.maxPlayers ? `${game.minPlayers}–${game.maxPlayers}` : game.minPlayers ? `${game.minPlayers}+` : "—", icon: "group" }, { label: "Time", value: game.playTime ? `${game.playTime}m` : "—", icon: "timer" }, { label: "Complexity", value: game.complexityWeight ? game.complexityWeight.toFixed(1) : "—", icon: "psychology" }] as stat (stat.label)}
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
				class="icon-filled material-symbols-outlined text-amber-400 text-[16px]">star</span
			>
			<span class="font-bold text-sm">{game.bggRating.toFixed(2)}</span>
			{#if game.usersRated}
				<span class="text-xs text-on-surface-variant"
					>({game.usersRated.toLocaleString()} ratings)</span
				>
			{/if}
		</div>
	{/if}
	{#if game.friendAvgRating !== null && game.friendRatingCount > 0}
		<div class="flex items-center gap-1">
			<span class="icon-filled material-symbols-outlined text-tertiary text-[16px]">group</span>
			<span class="text-xs font-bold text-on-surface">
				{game.friendRatingCount === 1
					? m("library.detail.friendAvgOne", { rating: game.friendAvgRating.toFixed(1) })
					: m("library.detail.friendAvg", {
							rating: game.friendAvgRating.toFixed(1),
							count: game.friendRatingCount,
						})}
			</span>
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
<div class="grid grid-cols-4 gap-2 mb-2">
	{#each actions as action (action.flag)}
		{@const active = myEntry?.[action.flag] ?? false}
		<button
			onclick={() => toggle(action.flag)}
			disabled={saving}
			aria-pressed={active}
			class="flex flex-col items-center gap-1 py-3 rounded-xl transition-colors
				{active ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}
				disabled:opacity-50"
		>
			<span class="material-symbols-outlined text-[20px]" class:icon-filled={active}>{action.icon}</span>
			<span class="text-[11px] font-bold text-center leading-tight">{m(active ? action.on : action.off)}</span>
		</button>
	{/each}
	<button
		onclick={() => (showAssistant = true)}
		class="flex flex-col items-center gap-1 py-3 rounded-xl transition-colors bg-tertiary-container text-on-tertiary-container"
	>
		<span class="material-symbols-outlined text-[20px]">smart_toy</span>
		<span class="text-[11px] font-bold">{m("library.action.askAi")}</span>
	</button>
</div>
<a
	href="/log-play?gameId={game.id}"
	class="flex items-center justify-center gap-2 w-full py-3 rounded-xl bg-surface-container-low text-primary text-sm font-bold"
>
	<span class="icon-filled material-symbols-outlined text-[18px]">sports_esports</span>
	{m("library.action.logPlay")}
</a>

<!-- Tabs -->
<div class="mt-6 flex gap-6 mb-4 overflow-x-auto hide-scrollbar">
	{#each detailTabs as tab (tab.id)}
		<button
			onclick={() => (activeTab = tab.id)}
			class="relative pb-3 text-sm font-bold whitespace-nowrap transition-colors {activeTab ===
			tab.id
				? 'text-primary'
				: 'text-on-surface-variant'}"
		>
			{m(tab.label)}
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
				{#each game.categories! as cat, i (i)}
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
				{#each game.mechanics! as mech, i (i)}
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
				{#each game.honors! as honor, i (i)}
					<div class="flex items-center gap-2">
						<span
							class="icon-filled material-symbols-outlined text-amber-400 text-[14px]"
							>emoji_events</span
						>
						<span class="text-xs text-on-surface">{honor}</span>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Details (designers, publishers, genre, BGG link) -->
	<!-- Designers & Publishers -->
	{#if hasChips(game.designers)}
		<div class="mb-4">
			<p
				class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2"
			>
				Designers
			</p>
			<div class="flex flex-wrap gap-2">
				{#each game.designers! as d, i (i)}
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
				{#each game.publishers!.slice(0, 5) as p, i (i)}
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
				{#each game.families! as f, i (i)}
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

	<!-- My plays, rating and notes -->
	<div class="mt-6 bg-surface-container-low rounded-2xl p-4 space-y-5">
		<div>
			<p class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2">
				{m("library.rating.label")}
			</p>
			<StarRating rating={myEntry?.personalRating ?? null} onrate={setRating} disabled={saving} size="md" />
		</div>

		<div>
			<p class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-3">
				{m("library.mine.playHistory", { count: myEntry?.playCount ?? 0 })}
			</p>
			{#if loadingLogs}
				<Skeleton class="h-10 w-full rounded-xl" />
			{:else if playLogs.length === 0}
				<p class="text-sm text-on-surface-variant">{m("library.mine.noPlays")}</p>
			{:else}
				<ul class="space-y-2">
					{#each playLogs as log, i (log.id)}
						<li class="flex items-start gap-3 bg-surface-container-lowest rounded-xl px-3 py-2">
							<span class="icon-filled material-symbols-outlined text-primary text-[18px] mt-0.5">sports_esports</span>
							<div class="flex-1 min-w-0">
								<p class="text-sm font-bold text-on-surface">
									{formatPlayDate(log.playedAt)}
									{#if i === 0}
										<span class="ml-1 text-[10px] text-primary font-bold uppercase tracking-widest">
											{m("library.mine.latest")}
										</span>
									{/if}
								</p>
								<p class="text-xs text-on-surface-variant">
									{[
										log.durationMinutes ? m("library.mine.minutes", { count: log.durationMinutes }) : null,
										log.playerCount ? m("library.mine.players", { count: log.playerCount }) : null,
										log.postId ? m("library.mine.fromPost") : null,
									]
										.filter(Boolean)
										.join(" · ")}
								</p>
								{#if log.notes}
									<p class="text-xs text-on-surface mt-1 whitespace-pre-line">{log.notes}</p>
								{/if}
							</div>
							<button
								type="button"
								onclick={() => deletePlay(log)}
								class="text-on-surface-variant hover:text-error p-1"
								aria-label={m("library.mine.deletePlay")}
							>
								<span class="material-symbols-outlined text-[18px]">delete</span>
							</button>
						</li>
					{/each}
				</ul>
			{/if}
		</div>

		<div>
			<p class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-2">
				{m("library.mine.notes")}
			</p>
			<textarea
				bind:value={notesValue}
				onblur={saveNotes}
				maxlength="1000"
				placeholder={m("library.mine.notesPlaceholder")}
				rows="3"
				class="w-full bg-surface-container-lowest rounded-xl px-3 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 resize-none focus:outline-none focus:ring-1 focus:ring-primary"
			></textarea>
			{#if savingNotes}
				<p class="text-xs text-on-surface-variant mt-1">{m("library.mine.saving")}</p>
			{/if}
		</div>
	</div>
{:else if activeTab === "howtoplay"}
	<HowToPlayTab gameId={game.id} />
{:else if tabLoading}
	<div class="space-y-3">
		{#each { length: 3 } as _, i (i)}
			<div class="flex items-center gap-3">
				<Skeleton class="w-10 h-10" rounded />
				<div class="flex-1 space-y-2">
					<Skeleton class="h-3 w-1/2 rounded-md" />
					<Skeleton class="h-3 w-1/3 rounded-md" />
				</div>
			</div>
		{/each}
	</div>
{:else if tabError}
	<div class="text-center py-10 space-y-3">
		<p class="text-sm text-on-surface-variant">{m("library.detail.loadFailed")}</p>
		<button onclick={retryTab} class="text-sm font-bold text-primary">{m("common.retry")}</button>
	</div>
{:else if activeTab === "reviews"}
	{#if !reviews || reviews.length === 0}
		<p class="text-sm text-on-surface-variant text-center py-10">{m("library.reviews.empty")}</p>
	{:else}
		<ul class="space-y-3">
			{#each reviews as review (review.user.id)}
				<li class="bg-surface-container-low rounded-2xl p-4">
					<a href="/profile/{review.user.id}" class="flex items-center gap-3">
						<Avatar src={review.user.avatarUrl} name={review.user.displayName ?? review.user.username} />
						<div class="flex-1 min-w-0">
							<p class="text-sm font-bold text-on-surface truncate">
								{review.user.displayName ?? review.user.username}
							</p>
							<p class="text-xs text-on-surface-variant">{playsLabel(review.playCount)}</p>
						</div>
						<StarRating rating={review.personalRating} />
					</a>
					{#if review.notes}
						<p class="text-sm text-on-surface mt-3 whitespace-pre-line">{review.notes}</p>
					{/if}
				</li>
			{/each}
		</ul>
	{/if}
{:else if activeTab === "friends"}
	{#if !friends || friends.length === 0}
		<p class="text-sm text-on-surface-variant text-center py-10">{m("library.friends.empty")}</p>
	{:else}
		<ul class="space-y-2">
			{#each friends as friend (friend.user.id)}
				<li>
					<a
						href="/profile/{friend.user.id}"
						class="flex items-center gap-3 bg-surface-container-low rounded-2xl px-4 py-3"
					>
						<Avatar src={friend.user.avatarUrl} name={friend.user.displayName ?? friend.user.username} />
						<div class="flex-1 min-w-0">
							<p class="text-sm font-bold text-on-surface truncate">
								{friend.user.displayName ?? friend.user.username}
							</p>
							<p class="text-xs text-on-surface-variant">{playsLabel(friend.playCount)}</p>
						</div>
						<StarRating rating={friend.personalRating} />
					</a>
				</li>
			{/each}
		</ul>
	{/if}
{:else if activeTab === "sessions"}
	{#if !sessions || sessions.length === 0}
		<p class="text-sm text-on-surface-variant text-center py-10">{m("library.sessions.empty")}</p>
	{:else}
		<ul class="space-y-3">
			{#each sessions as post (post.id)}
				<li>
					<a href="/posts/{post.id}" class="flex gap-3 bg-surface-container-low rounded-2xl p-3">
						{#if post.imageUrls.length > 0}
							<img
								src={post.imageUrls[0]}
								alt=""
								class="w-20 h-20 rounded-xl object-cover flex-shrink-0"
								loading="lazy"
							/>
						{/if}
						<div class="flex-1 min-w-0">
							<div class="flex items-center gap-2">
								<Avatar
									src={post.author.avatarUrl}
									name={post.author.displayName ?? post.author.username}
									size="xs"
								/>
								<p class="text-sm font-bold text-on-surface truncate">
									{post.author.displayName ?? post.author.username}
								</p>
							</div>
							<p class="text-[11px] text-on-surface-variant mt-0.5">
								{formatPlayDate(post.playedAt ?? post.createdAt)}
							</p>
							{#if post.caption}
								<p class="text-sm text-on-surface mt-1 line-clamp-2">{post.caption}</p>
							{/if}
							{#if post.taggedUsers.length > 0}
								<div class="flex -space-x-1.5 mt-2">
									{#each post.taggedUsers.slice(0, 6) as tagged (tagged.id)}
										<Avatar
											src={tagged.avatarUrl}
											name={tagged.username}
											size="xs"
											className="ring-2 ring-surface-container-low"
										/>
									{/each}
								</div>
							{/if}
						</div>
					</a>
				</li>
			{/each}
		</ul>
		{#if sessionsHasMore}
			<button
				onclick={moreSessions}
				disabled={loadingMoreSessions}
				class="w-full mt-4 py-3 rounded-xl bg-surface-container-high text-sm font-bold text-on-surface disabled:opacity-50"
			>
				{loadingMoreSessions ? m("common.loading") : m("common.loadMore")}
			</button>
		{/if}
	{/if}
{/if}

<AiAssistantDrawer
	bind:show={showAssistant}
	gameId={game.id}
	gameTitle={game.title}
/>
