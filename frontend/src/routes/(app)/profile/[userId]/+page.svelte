<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import Button from '$lib/components/ui/Button.svelte';
</script>

<svelte:head><title>Profile — Meeple & Hearth</title></svelte:head>

<div class="flex flex-col items-center gap-3 mb-6">
	<Skeleton class="w-16 h-16" rounded />
	<div class="text-center space-y-2">
		<Skeleton class="h-5 w-36 mx-auto" />
		<Skeleton class="h-3 w-24 mx-auto" />
	</div>
</div>

<div class="grid grid-cols-3 gap-3 mb-6">
	{#each ['Games', 'Sessions', 'Friends'] as stat}
		<div class="bg-surface-container-low p-4 rounded-xl text-center">
			<p class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant opacity-70">{stat}</p>
			<Skeleton class="h-6 w-10 mx-auto mt-1" />
		</div>
	{/each}
</div>

<Button fullWidth>Add Friend</Button>
