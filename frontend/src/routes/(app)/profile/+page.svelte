<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();

	const gamesOwned = $derived(data.collection.filter((g: { isOwned: boolean }) => g.isOwned).length);
	const favorites = $derived(data.collection.filter((g: { isFavorited: boolean }) => g.isFavorited));
</script>

<svelte:head><title>Profile — Meeple & Hearth</title></svelte:head>

<!-- Profile header -->
<div class="flex flex-col items-center gap-4 mb-6 pt-2">
	<div class="relative">
		<Avatar
			src={data.user?.avatarUrl}
			name={data.user?.displayName ?? data.user?.username ?? '?'}
			size="xl"
		/>
	</div>
	<div class="text-center space-y-1">
		<h2 class="text-2xl font-extrabold font-headline">
			{data.user?.displayName ?? data.user?.username ?? ''}
		</h2>
		<p class="text-sm text-on-surface-variant">@{data.user?.username ?? ''}</p>
		{#if data.user?.location}
			<p class="text-xs text-on-surface-variant flex items-center justify-center gap-1">
				<span class="material-symbols-outlined text-[14px]">location_on</span>
				{data.user.location}
			</p>
		{/if}
		{#if data.user?.bio}
			<p class="text-sm text-on-surface mt-2 max-w-xs">{data.user.bio}</p>
		{/if}
	</div>
</div>

<!-- Stats bento -->
<div class="grid grid-cols-3 gap-3 mb-4">
	<div class="bg-surface-container-low p-4 rounded-xl text-center">
		<p class="text-2xl font-extrabold font-headline">{gamesOwned}</p>
		<p class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mt-0.5">Games</p>
	</div>
	<div class="bg-surface-container-low p-4 rounded-xl text-center">
		<p class="text-2xl font-extrabold font-headline">{data.posts.length}</p>
		<p class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mt-0.5">Posts</p>
	</div>
	<div class="bg-surface-container-low p-4 rounded-xl text-center">
		<p class="text-2xl font-extrabold font-headline">—</p>
		<p class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mt-0.5">Friends</p>
	</div>
</div>

<!-- Edit profile -->
<a
	href="/settings"
	class="block w-full text-center py-2.5 bg-surface-container-high rounded-full text-sm font-label font-bold text-on-surface-variant hover:bg-surface-container-highest transition-colors mb-6"
>
	Edit Profile
</a>

<!-- Favorite games carousel -->
{#if favorites.length > 0}
	<section class="mb-6">
		<div class="flex justify-between items-center mb-3">
			<h3 class="text-base font-headline font-bold">Favorite Games</h3>
			<a href="/library?tab=favorites" class="text-primary text-xs font-label font-bold">See all</a>
		</div>
		<div class="flex gap-3 overflow-x-auto hide-scrollbar -mx-4 px-4 pb-1">
			{#each favorites as ug (ug.id)}
				<a href="/library/{ug.game.id}" class="flex-shrink-0 space-y-1.5 group">
					<div class="w-28 h-40 rounded-xl overflow-hidden bg-surface-container-high shadow-sm group-hover:-translate-y-1 group-hover:shadow-md transition-all duration-300">
						{#if ug.game.thumbnailUrl}
							<img
								src={ug.game.thumbnailUrl}
								alt={ug.game.title}
								class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
								loading="lazy"
							/>
						{:else}
							<div class="w-full h-full flex items-center justify-center">
								<span class="material-symbols-outlined text-2xl text-on-surface-variant opacity-40">casino</span>
							</div>
						{/if}
					</div>
					<p class="w-28 text-xs font-semibold text-on-surface line-clamp-2 leading-tight">{ug.game.title}</p>
				</a>
			{/each}
		</div>
	</section>
{/if}

<!-- Posts grid -->
<section>
	{#if data.posts.length > 0}
		<h3 class="text-base font-headline font-bold mb-3">Posts</h3>
	{/if}
	{#if data.posts.length === 0}
		<div class="text-center py-8 text-on-surface-variant">
			<span class="material-symbols-outlined text-4xl mb-2 block opacity-40">photo_library</span>
			<p class="text-sm">No posts yet</p>
		</div>
	{:else}
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
	{/if}
</section>
