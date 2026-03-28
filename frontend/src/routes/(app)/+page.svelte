<script lang="ts">
	import { getGreeting } from '$lib/utils/date';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const greeting = getGreeting();
</script>

<svelte:head>
	<title>Home — Meeple & Hearth</title>
</svelte:head>

<!-- Greeting -->
<section class="space-y-1 mb-8">
	<h2 class="text-3xl font-extrabold tracking-tight font-headline text-on-surface">
		{greeting}, {data.user?.displayName ?? 'there'}!
	</h2>
	<p class="text-sm text-on-surface-variant">No upcoming events.</p>
</section>

<!-- Feed placeholder -->
<section class="space-y-4">
	{#each { length: 3 } as _}
		<div class="bg-surface-container-lowest rounded-xl p-4 space-y-3 shadow-[0_12px_32px_rgba(25,28,29,0.06)]">
			<div class="flex items-center gap-3">
				<Skeleton class="w-10 h-10" rounded />
				<div class="flex-1 space-y-2">
					<Skeleton class="h-3 w-32" />
					<Skeleton class="h-2 w-20" />
				</div>
			</div>
			<Skeleton class="w-full h-48" />
			<Skeleton class="h-3 w-3/4" />
		</div>
	{/each}
</section>
