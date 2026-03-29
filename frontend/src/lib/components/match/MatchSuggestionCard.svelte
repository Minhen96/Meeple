<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { matchesApi } from '$lib/api/matches';
	import { goto } from '$app/navigation';
	import type { MatchGroup } from '$lib/types';

	interface Props {
		group: MatchGroup;
		onDismiss: (id: string) => void;
	}

	let { group, onDismiss }: Props = $props();
	let loading = $state(false);

	function formatWindow(): string {
		if (!group.overlapStart) return 'Any time';
		const start = new Date(group.overlapStart);
		const end = group.overlapEnd ? new Date(group.overlapEnd) : null;
		const dateStr = start.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
		const timeStr = start.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
		const endStr = end ? ' – ' + end.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }) : '';
		return `${dateStr} · ${timeStr}${endStr}`;
	}

	async function handleAccept() {
		loading = true;
		try {
			const event = await matchesApi.acceptMatch(group.id);
			goto(`/events/${event.id}`);
		} finally {
			loading = false;
		}
	}

	async function handleDismiss() {
		loading = true;
		try {
			await matchesApi.dismissMatch(group.id);
			onDismiss(group.id);
		} finally {
			loading = false;
		}
	}
</script>

<div class="bg-gradient-to-br from-primary/10 to-primary-container/20 rounded-2xl p-4 space-y-3">
	<div class="flex items-center gap-2">
		<span class="material-symbols-outlined text-primary text-lg">star</span>
		<p class="text-xs font-bold uppercase tracking-widest text-primary">Match Found!</p>
	</div>

	<div class="flex items-center gap-3">
		{#if group.game.thumbnailUrl}
			<img src={group.game.thumbnailUrl} alt={group.game.title}
				class="w-12 h-12 rounded-xl object-cover flex-shrink-0" />
		{/if}
		<div class="flex-1 min-w-0">
			<p class="font-bold text-on-surface truncate">{group.game.title}</p>
			<p class="text-xs text-on-surface-variant mt-0.5 flex items-center gap-1">
				<span class="material-symbols-outlined text-sm">schedule</span>
				{formatWindow()}
			</p>
		</div>
	</div>

	<div class="flex items-center gap-1.5">
		{#each group.members as member}
			<Avatar src={member.avatarUrl} size="xs" />
		{/each}
		<span class="text-xs text-on-surface-variant ml-1">
			{group.members.map(m => m.displayName ?? m.username).join(', ')}
		</span>
	</div>

	<div class="flex gap-2 pt-1">
		<button
			onclick={handleAccept}
			disabled={loading}
			class="flex-1 bg-primary text-on-primary text-sm font-semibold py-2.5 rounded-xl transition-opacity disabled:opacity-60"
		>
			Create Event
		</button>
		<button
			onclick={handleDismiss}
			disabled={loading}
			class="px-4 bg-surface-container text-on-surface-variant text-sm font-semibold py-2.5 rounded-xl transition-opacity disabled:opacity-60"
		>
			Dismiss
		</button>
	</div>
</div>
