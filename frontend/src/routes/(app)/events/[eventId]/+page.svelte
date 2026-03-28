<script lang="ts">
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import Button from '$lib/components/ui/Button.svelte';
</script>

<svelte:head><title>Event — Meeple & Hearth</title></svelte:head>

<!-- Hero -->
<div class="relative -mx-4 -mt-24 mb-6">
	<Skeleton class="w-full h-[280px]" />
</div>

<!-- Info -->
<div class="space-y-4">
	<Skeleton class="h-6 w-3/4" />
	<div class="grid grid-cols-3 gap-2">
		{#each { length: 3 } as _}
			<div class="bg-surface-container-low rounded-xl p-3 space-y-1">
				<Skeleton class="h-3 w-1/2 mx-auto" />
				<Skeleton class="h-4 w-3/4 mx-auto" />
			</div>
		{/each}
	</div>
</div>

<!-- Action -->
<div class="fixed bottom-24 left-0 right-0 px-4 max-w-lg mx-auto">
	<Button fullWidth>Join Event</Button>
</div>
