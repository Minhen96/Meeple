<script lang="ts">
	import Skeleton from '$lib/components/ui/Skeleton.svelte';

	/** Loading placeholder matching PostCard (SCREENS_AND_STATES 14.6). */
	interface Props {
		count?: number;
	}
	let { count = 2 }: Props = $props();
</script>

<div class="space-y-4" aria-hidden="true">
	{#each Array.from({ length: count }, (_, i) => i) as i (i)}
		<div class="overflow-hidden rounded-2xl bg-surface-container-lowest">
			<div class="flex items-center gap-3 p-4">
				<Skeleton rounded class="h-10 w-10" />
				<div class="space-y-2">
					<Skeleton class="h-3 w-28" />
					<Skeleton class="h-2.5 w-20" />
				</div>
			</div>
			<Skeleton class="h-72 w-full" />
			<div class="space-y-2 p-4">
				<Skeleton class="h-3 w-16" />
				<Skeleton class="h-3 w-36" />
				<Skeleton class="h-3 w-24" />
			</div>
		</div>
	{/each}
</div>
