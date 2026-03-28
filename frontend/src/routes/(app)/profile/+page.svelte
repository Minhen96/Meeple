<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();

	const gamesOwned = $derived(data.collection.filter((g: { isOwned: boolean }) => g.isOwned).length);
</script>

<svelte:head><title>Profile — Meeple & Hearth</title></svelte:head>

<!-- Profile header -->
<div class="flex flex-col items-center gap-3 mb-6">
	<Avatar
		src={data.user?.avatarUrl}
		name={data.user?.displayName ?? data.user?.username ?? '?'}
		size="xl"
	/>
	<div class="text-center">
		<h2 class="text-2xl font-extrabold font-headline">
			{data.user?.displayName ?? data.user?.username ?? ''}
		</h2>
		<p class="text-sm text-on-surface-variant">@{data.user?.username ?? ''}</p>
		{#if data.user?.bio}
			<p class="text-sm text-on-surface mt-2 max-w-xs">{data.user.bio}</p>
		{/if}
		{#if data.user?.location}
			<p class="text-xs text-on-surface-variant mt-1 flex items-center justify-center gap-1">
				<span class="material-symbols-outlined text-[14px]">location_on</span>
				{data.user.location}
			</p>
		{/if}
	</div>
</div>

<!-- Stats bento -->
<div class="grid grid-cols-3 gap-3 mb-6">
	<div class="bg-surface-container-low p-4 rounded-xl text-center">
		<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant opacity-70">Games</p>
		<p class="text-2xl font-extrabold font-headline mt-1">{gamesOwned}</p>
	</div>
	<div class="bg-surface-container-low p-4 rounded-xl text-center">
		<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant opacity-70">Posts</p>
		<p class="text-2xl font-extrabold font-headline mt-1">{data.posts.length}</p>
	</div>
	<div class="bg-surface-container-low p-4 rounded-xl text-center">
		<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant opacity-70">Friends</p>
		<p class="text-2xl font-extrabold font-headline mt-1">—</p>
	</div>
</div>

<!-- Edit profile button -->
<a
	href="/settings"
	class="block w-full text-center py-2.5 bg-surface-container-high rounded-full text-sm font-label font-bold text-on-surface-variant hover:bg-surface-container-highest transition-colors mb-6"
>
	Edit Profile
</a>

<!-- Posts grid -->
{#if data.posts.length === 0}
	<div class="text-center py-8 text-on-surface-variant">
		<span class="material-symbols-outlined text-4xl mb-2 block opacity-40">photo_library</span>
		<p class="text-sm">No posts yet</p>
	</div>
{:else}
	<div class="grid grid-cols-3 gap-1">
		{#each data.posts as post (post.id)}
			<a href="/posts/{post.id}" class="aspect-square overflow-hidden bg-surface-container-high">
				{#if post.imageUrls.length > 0}
					<img
						src={post.imageUrls[0]}
						alt="Post"
						class="w-full h-full object-cover"
						loading="lazy"
					/>
				{:else}
					<div class="w-full h-full flex items-center justify-center">
						<span class="material-symbols-outlined text-on-surface-variant opacity-40">image</span>
					</div>
				{/if}
			</a>
		{/each}
	</div>
{/if}
