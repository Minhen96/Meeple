<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();
</script>

<svelte:head><title>Profile — Meeple & Hearth</title></svelte:head>

<!-- Profile header -->
<div class="flex flex-col items-center gap-3 mb-6">
	<Avatar
		src={data.user?.avatarUrl}
		name={data.user?.displayName ?? ''}
		size="xl"
	/>
	<div class="text-center">
		<h2 class="text-2xl font-extrabold font-headline">{data.user?.displayName ?? ''}</h2>
		<p class="text-sm text-on-surface-variant">@{data.user?.username ?? ''}</p>
	</div>
</div>

<!-- Stats bento -->
<div class="grid grid-cols-3 gap-3 mb-6">
	{#each ['Games', 'Sessions', 'Friends'] as stat}
		<div class="bg-surface-container-low p-4 rounded-xl text-center">
			<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant opacity-70">{stat}</p>
			<p class="text-2xl font-extrabold font-headline mt-1">—</p>
		</div>
	{/each}
</div>

<!-- Edit profile button -->
<a href="/settings/profile" class="block w-full text-center py-2.5 bg-surface-container-high rounded-full text-sm font-label font-bold text-on-surface-variant hover:bg-surface-container-highest transition-colors mb-6">
	Edit Profile
</a>

<!-- Posts grid placeholder -->
<div class="grid grid-cols-3 gap-1">
	{#each { length: 9 } as _}
		<Skeleton class="aspect-square" />
	{/each}
</div>
