<script lang="ts">
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();
</script>

<svelte:head><title>Game — Meeple & Hearth</title></svelte:head>

<!-- Hero placeholder -->
<div class="relative -mx-4 -mt-24 mb-6">
	<Skeleton class="w-full h-[400px]" />
</div>

<!-- Action buttons -->
<div class="space-y-3">
	<Button fullWidth>Add to Collection</Button>
	<Button variant="secondary" fullWidth>Wishlist</Button>
	<Button variant="tertiary" fullWidth>
		<span class="material-symbols-outlined text-[18px]">smart_toy</span>
		AI Rules Assistant
	</Button>
</div>
