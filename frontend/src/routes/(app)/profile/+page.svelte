<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import SetupStatusModal from '$lib/components/admin/SetupStatusModal.svelte';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let showSetupModal = $state(false);

	const gamesOwned  = $derived(data.collection.filter((g: { isOwned: boolean }) => g.isOwned).length);
	const totalPlays  = $derived(data.collection.reduce((sum: number, g: { playCount: number }) => sum + g.playCount, 0));
	const favorites   = $derived(data.collection.filter((g: { isFavorited: boolean }) => g.isFavorited));

	function formatTimestamp(iso: string) {
		const d = new Date(iso);
		const now = new Date();
		const diffMs = now.getTime() - d.getTime();
		const diffDays = Math.floor(diffMs / 86_400_000);
		const time = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
		if (diffDays === 0) return `Today • ${time}`;
		if (diffDays === 1) return `Yesterday • ${time}`;
		if (diffDays < 7)  return `${diffDays} days ago • ${time}`;
		return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ` • ${time}`;
	}
</script>

<svelte:head><title>Profile — Meeple</title></svelte:head>

{#if showSetupModal}
	<SetupStatusModal onClose={() => (showSetupModal = false)} />
{/if}

<!-- Profile Header -->
<section class="relative flex flex-col items-center gap-6 mb-10 pt-4">
	<!-- Settings Gear (Top Right of Section) -->
	<a 
		href="/settings" 
		class="absolute top-0 right-0 p-2 text-on-surface-variant hover:text-primary transition-colors active:scale-90"
		aria-label="Settings"
	>
		<span class="material-symbols-outlined text-[24px]">settings</span>
	</a>

	<!-- Avatar with subtle tilt -->
	<div class="relative">
		<div class="rotate-2 rounded-2xl overflow-hidden w-28 h-28 shadow-[0_12px_32px_rgba(0,0,0,0.10)] ring-4 ring-surface">
			<Avatar
				src={data.user?.avatarUrl}
				name={data.user?.displayName ?? data.user?.username ?? '?'}
				size="none"
				class="w-full h-full object-cover scale-105 rounded-none"
			/>
		</div>
		<!-- Verified-style badge -->
		<div class="absolute -bottom-2 -right-2 w-8 h-8 bg-secondary-container rounded-full shadow-md flex items-center justify-center">
			<span class="material-symbols-outlined text-on-secondary-container text-[16px]" style="font-variation-settings: 'FILL' 1;">verified</span>
		</div>
	</div>

	<div class="text-center space-y-1.5 px-4 w-full">
		<h2 class="text-3xl font-extrabold font-headline tracking-tight flex items-center justify-center gap-2">
			{data.user?.displayName ?? data.user?.username ?? ''}
			<a href="/settings/profile" class="p-1.5 rounded-full hover:bg-surface-container-high text-on-surface-variant/40 hover:text-primary transition-all active:scale-90" aria-label="Edit Profile">
				<span class="material-symbols-outlined text-[18px]">edit</span>
			</a>
		</h2>
		
		{#if data.user?.location}
			<p class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant flex items-center justify-center gap-1 opacity-70">
				<span class="material-symbols-outlined text-[14px]">location_on</span>
				{data.user.location}
			</p>
		{/if}
		
		{#if data.user?.bio}
			<p class="text-sm text-on-surface-variant max-w-xs mx-auto leading-relaxed">{data.user.bio}</p>
		{/if}
	</div>

	<!-- Secondary Actions (Admin/Management) -->
	{#if data.user?.isAdmin}
		<div class="flex gap-2 w-full max-w-xs">
			<a
				href="/admin/rulebooks"
				class="flex-1 px-4 py-2 bg-surface-container-high/50 hover:bg-surface-container-high text-on-surface font-bold text-[11px] uppercase tracking-wider rounded-xl flex items-center justify-center gap-1.5 transition-all"
			>
				<span class="material-symbols-outlined text-[14px]">rate_review</span>
				Review Queue
			</a>
			<button
				onclick={() => (showSetupModal = true)}
				class="px-4 py-2 bg-surface-container-high/50 hover:bg-surface-container-high text-on-surface font-bold text-[11px] uppercase tracking-wider rounded-xl flex items-center justify-center gap-1.5 transition-all"
			>
				<span class="material-symbols-outlined text-[14px]">monitoring</span>
				System
			</button>
		</div>
	{/if}
</section>

<!-- Stats Bento — 3 col, middle highlighted -->
<div class="grid grid-cols-3 gap-3 mb-8">
	<div class="bg-surface-container-low p-4 rounded-2xl text-center">
		<p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant opacity-70 mb-1">Owned</p>
		<p class="text-2xl font-extrabold font-headline">{gamesOwned}</p>
	</div>
	<div class="bg-surface-container-low p-4 rounded-2xl text-center border-l-4 border-primary">
		<p class="font-label text-[10px] font-bold uppercase tracking-widest text-primary opacity-70 mb-1">Sessions</p>
		<p class="text-2xl font-extrabold font-headline">{totalPlays}</p>
	</div>
	<div class="bg-surface-container-low p-4 rounded-2xl text-center">
		<p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant opacity-70 mb-1">Friends</p>
		<p class="text-2xl font-extrabold font-headline">—</p>
	</div>
</div>

<!-- Favorite Games -->
{#if favorites.length > 0}
	<section class="mb-8">
		<div class="flex items-center justify-between mb-4">
			<h3 class="text-xl font-extrabold font-headline tracking-tight">Favorite Games</h3>
			<a href="/library?tab=favorites" class="text-primary text-sm font-bold flex items-center gap-1">
				See All <span class="material-symbols-outlined text-[16px]">arrow_forward</span>
			</a>
		</div>
		<div class="flex gap-4 overflow-x-auto hide-scrollbar -mx-4 px-4 pb-3">
			{#each favorites as ug (ug.id)}
				<a href="/library/{ug.game.id}" class="flex-shrink-0 w-36 group">
					<div class="h-48 bg-surface-container rounded-2xl overflow-hidden shadow-[0_8px_24px_rgba(0,0,0,0.06)] transition-transform duration-300 group-hover:scale-[1.02] group-hover:-rotate-1">
						{#if ug.game.thumbnailUrl}
							<img
								src={ug.game.thumbnailUrl}
								alt={ug.game.title}
								class="w-full h-full object-cover"
								loading="lazy"
							/>
						{:else}
							<div class="w-full h-full flex items-center justify-center">
								<span class="material-symbols-outlined text-3xl text-on-surface-variant opacity-30">casino</span>
							</div>
						{/if}
					</div>
					<div class="mt-2 px-0.5">
						<p class="text-sm font-bold text-on-surface line-clamp-1 leading-snug">{ug.game.title}</p>
						{#if ug.game.yearPublished}
							<p class="text-xs text-on-surface-variant font-label mt-0.5">{ug.game.yearPublished}</p>
						{/if}
					</div>
				</a>
			{/each}
		</div>
	</section>
{/if}

<!-- Recent Activity Timeline -->
{#if data.activity.length > 0}
	<section class="mb-8">
		<h3 class="text-xl font-extrabold font-headline tracking-tight mb-6">Recent Activity</h3>
		<div class="space-y-8 max-w-lg">
			{#each data.activity as item, i}
				<div class="relative pl-10 border-l-2 border-surface-container-high">
					<!-- Circle icon -->
					<div class="absolute -left-[13px] top-0 w-6 h-6 {i % 2 === 0 ? 'bg-primary' : 'bg-tertiary'} rounded-full ring-4 ring-surface flex items-center justify-center">
						<span class="material-symbols-outlined text-white text-[12px]" style="font-variation-settings: 'FILL' 1;">sports_esports</span>
					</div>

					<div class="space-y-2">
						<!-- Timestamp -->
						<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant">{formatTimestamp(item.playedAt)}</p>

						<!-- Activity card -->
						<a
							href="/library/{item.game.id}"
							class="flex items-start gap-4 bg-surface-container-lowest p-4 rounded-2xl shadow-[0_4px_16px_rgba(0,0,0,0.04)] border-l-4 {i % 2 === 0 ? 'border-secondary' : 'border-tertiary-container'} hover:shadow-[0_8px_24px_rgba(0,0,0,0.07)] transition-all"
						>
							<div class="w-14 h-14 rounded-xl overflow-hidden flex-shrink-0 bg-surface-container">
								{#if item.game.thumbnailUrl}
									<img src={item.game.thumbnailUrl} alt={item.game.title} class="w-full h-full object-cover" loading="lazy" />
								{:else}
									<div class="w-full h-full flex items-center justify-center">
										<span class="material-symbols-outlined text-on-surface-variant opacity-40">casino</span>
									</div>
								{/if}
							</div>
							<div class="flex-1 min-w-0">
								<h4 class="font-bold text-base text-on-surface leading-tight">Played {item.game.title}</h4>
								<div class="flex items-center gap-2 mt-1.5">
									<span class="text-xs font-label font-bold text-secondary uppercase tracking-wider">Play logged</span>
								</div>
							</div>
						</a>
					</div>
				</div>
			{/each}
		</div>
	</section>
{:else}
	<section class="mb-8">
		<h3 class="text-xl font-extrabold font-headline tracking-tight mb-4">Recent Activity</h3>
		<div class="bg-surface-container-low rounded-2xl p-8 text-center">
			<span class="material-symbols-outlined text-4xl text-primary/20 mb-2 block">sports_esports</span>
			<p class="text-sm text-on-surface-variant">No plays logged yet. Use the + button to log your first session.</p>
		</div>
	</section>
{/if}

<!-- Posts grid -->
{#if data.posts.length > 0}
	<section>
		<h3 class="text-xl font-extrabold font-headline tracking-tight mb-4">Posts</h3>
		<div class="grid grid-cols-3 gap-1 -mx-4">
			{#each data.posts as post (post.id)}
				<a href="/posts/{post.id}" class="aspect-square overflow-hidden bg-surface-container-high">
					{#if post.imageUrls.length > 0}
						<img
							src={post.imageUrls[0]}
							alt="Post"
							class="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
							loading="lazy"
						/>
					{:else}
						<div class="w-full h-full flex items-center justify-center bg-surface-container">
							<span class="material-symbols-outlined text-on-surface-variant opacity-40">image</span>
						</div>
					{/if}
				</a>
			{/each}
		</div>
	</section>
{/if}
