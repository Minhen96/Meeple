<script lang="ts">
	import Skeleton from '$lib/components/ui/Skeleton.svelte';

	let activeTab = $state<'all' | 'collection' | 'wishlist' | 'favorites'>('all');
	let query = $state('');

	const tabs = [
		{ id: 'all', label: 'All Games' },
		{ id: 'collection', label: 'My Collection' },
		{ id: 'wishlist', label: 'Wishlist' },
		{ id: 'favorites', label: 'Favorites' }
	] as const;
</script>

<svelte:head><title>Library — Meeple & Hearth</title></svelte:head>

<!-- Search bar -->
<div class="sticky top-24 z-40 bg-background pb-2">
	<input
		type="search"
		placeholder="Search games..."
		bind:value={query}
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
	/>

	<!-- Tabs -->
	<div class="flex gap-2 mt-3 overflow-x-auto hide-scrollbar">
		{#each tabs as tab}
			<button
				onclick={() => (activeTab = tab.id)}
				class="flex-shrink-0 px-4 py-2 rounded-full text-sm font-label font-bold transition-colors {activeTab === tab.id ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
			>
				{tab.label}
			</button>
		{/each}
	</div>
</div>

<!-- Game grid skeleton -->
<div class="grid grid-cols-3 gap-3 mt-4">
	{#each { length: 9 } as _}
		<div class="space-y-2">
			<Skeleton class="w-full aspect-[3/4]" />
			<Skeleton class="h-3 w-4/5" />
			<Skeleton class="h-2 w-1/2" />
		</div>
	{/each}
</div>
