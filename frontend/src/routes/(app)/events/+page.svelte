<script lang="ts">
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import Button from '$lib/components/ui/Button.svelte';

	let view = $state<'list' | 'calendar'>('list');
	let tab = $state<'upcoming' | 'past'>('upcoming');
</script>

<svelte:head><title>Events — Meeple & Hearth</title></svelte:head>

<!-- View toggle -->
<div class="flex items-center justify-between mb-4">
	<div class="flex gap-2">
		<button
			onclick={() => (tab = 'upcoming')}
			class="px-4 py-2 rounded-full text-sm font-label font-bold {tab === 'upcoming' ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
		>Upcoming</button>
		<button
			onclick={() => (tab = 'past')}
			class="px-4 py-2 rounded-full text-sm font-label font-bold {tab === 'past' ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
		>Past</button>
	</div>
	<button
		onclick={() => (view = view === 'list' ? 'calendar' : 'list')}
		class="text-on-surface-variant hover:text-on-surface transition-colors"
		aria-label="Toggle calendar view"
	>
		<span class="material-symbols-outlined">{view === 'list' ? 'calendar_month' : 'list'}</span>
	</button>
</div>

<!-- Event list skeletons -->
<div class="space-y-4">
	{#each { length: 3 } as _}
		<div class="bg-surface-container-lowest rounded-xl p-4 space-y-3 shadow-[0_12px_32px_rgba(25,28,29,0.06)]">
			<div class="flex gap-3">
				<Skeleton class="w-16 h-16" />
				<div class="flex-1 space-y-2">
					<Skeleton class="h-4 w-3/4" />
					<Skeleton class="h-3 w-1/2" />
					<Skeleton class="h-3 w-2/3" />
				</div>
			</div>
		</div>
	{/each}
</div>

<!-- FAB -->
<a href="/events/create" class="fixed bottom-24 right-4 w-14 h-14 bg-gradient-to-br from-primary to-primary-container rounded-full flex items-center justify-center shadow-[0_8px_24px_rgba(137,81,0,0.30)] hover:scale-110 active:scale-95 transition-all z-40">
	<span class="material-symbols-outlined text-on-primary text-2xl">add</span>
</a>
