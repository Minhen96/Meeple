<script lang="ts">
	// Shimmer skeletons for the standard layouts (SCREENS_AND_STATES section 14.6).
	import Skeleton from './Skeleton.svelte';
	import { m } from '$lib/i18n';

	interface Props {
		variant: 'post' | 'game' | 'user' | 'stat';
		count?: number;
	}

	let { variant, count = 1 }: Props = $props();
	const items = $derived(Array.from({ length: Math.max(1, count) }, (_, i) => i));
</script>

<div role="status" aria-busy="true" aria-label={m('common.loading')} class="contents">
	{#each items as i (i)}
		{#if variant === 'post'}
			<div class="space-y-3 py-2">
				<div class="flex items-center gap-3">
					<Skeleton rounded class="w-10 h-10" />
					<div class="space-y-2">
						<Skeleton class="h-3 w-[120px]" />
						<Skeleton class="h-3 w-20" />
					</div>
				</div>
				<Skeleton class="h-[300px] w-full rounded-2xl" />
				<div class="space-y-2">
					<Skeleton class="h-3 w-[60px]" />
					<Skeleton class="h-3 w-[140px]" />
					<Skeleton class="h-3 w-[90px]" />
				</div>
			</div>
		{:else if variant === 'game'}
			<div class="space-y-2">
				<Skeleton class="aspect-[4/3] w-full rounded-2xl" />
				<Skeleton class="h-3 w-20" />
				<Skeleton class="h-3 w-[50px]" />
			</div>
		{:else if variant === 'user'}
			<div class="flex items-center gap-3 py-2">
				<Skeleton rounded class="w-12 h-12" />
				<div class="flex-1 space-y-2">
					<Skeleton class="h-3 w-[100px]" />
					<Skeleton class="h-3 w-[70px]" />
				</div>
				<Skeleton class="h-8 w-20 rounded-full" />
			</div>
		{:else}
			<Skeleton class="h-20 w-full rounded-2xl" />
		{/if}
	{/each}
</div>
