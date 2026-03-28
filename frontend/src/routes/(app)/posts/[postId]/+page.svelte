<script lang="ts">
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
</script>

<svelte:head><title>Post — Meeple & Hearth</title></svelte:head>

<div class="space-y-4">
	<div class="flex items-center gap-3">
		<Skeleton class="w-10 h-10" rounded />
		<div class="space-y-2">
			<Skeleton class="h-3 w-28" />
			<Skeleton class="h-2 w-20" />
		</div>
	</div>
	<Skeleton class="w-full aspect-square" />
	<div class="flex gap-4 text-on-surface-variant">
		<span class="material-symbols-outlined cursor-pointer hover:text-error transition-colors">favorite</span>
		<span class="material-symbols-outlined cursor-pointer hover:text-primary transition-colors">chat_bubble</span>
		<span class="material-symbols-outlined cursor-pointer ml-auto">share</span>
	</div>
	<Skeleton class="h-3 w-full" />
	<Skeleton class="h-3 w-2/3" />
</div>
