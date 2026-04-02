<script lang="ts">
	import type { PageData } from './$types';
	import { eventsApi } from '$lib/api/events';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let event = $state(data.event);
	let loading = $state(false);

	const isHost = $derived(data.user?.id === event.host.id);

	function formatDateTime(iso: string) {
		return new Date(iso).toLocaleString('en-US', {
			weekday: 'long', month: 'long', day: 'numeric',
			hour: 'numeric', minute: '2-digit'
		});
	}

	async function rsvp(status: 'ACCEPTED' | 'DECLINED') {
		loading = true;
		try {
			event = await eventsApi.rsvp(event.id, status);
			toast.success(status === 'ACCEPTED' ? "You're in!" : 'RSVP declined');
		} catch (err: unknown) {
			toast.error(err instanceof Error ? err.message : 'Could not update RSVP');
		} finally {
			loading = false;
		}
	}

	async function leave() {
		loading = true;
		try {
			await eventsApi.leaveEvent(event.id);
			toast.success('Left event');
			goto('/events');
		} catch {
			toast.error('Could not leave event');
			loading = false;
		}
	}

	async function deleteEvent() {
		if (!confirm('Delete this event? This cannot be undone.')) return;
		loading = true;
		try {
			await eventsApi.deleteEvent(event.id);
			toast.success('Event deleted');
			goto('/events');
		} catch {
			toast.error('Could not delete event');
			loading = false;
		}
	}
</script>

<svelte:head><title>{event.title} — Meeple</title></svelte:head>

<div class="space-y-4 mb-6">
	<!-- Title + status -->
	<div class="flex items-start justify-between gap-3">
		<h2 class="text-2xl font-extrabold font-headline">{event.title}</h2>
		<span class="flex-shrink-0 text-xs font-semibold px-2.5 py-1 rounded-full
			{event.status === 'OPEN' ? 'bg-tertiary/15 text-tertiary' :
			 event.status === 'FULL' ? 'bg-error/15 text-error' :
			 'bg-surface-container-high text-on-surface-variant'}">
			{event.status}
		</span>
	</div>

	<!-- Meta -->
	<div class="space-y-2 text-sm">
		<div class="flex items-center gap-2">
			<span class="material-symbols-outlined text-[18px] text-on-surface-variant">calendar_month</span>
			{formatDateTime(event.scheduledAt)}
		</div>
		{#if event.location}
			<div class="flex items-center gap-2">
				<span class="material-symbols-outlined text-[18px] text-on-surface-variant">location_on</span>
				{event.location}
			</div>
		{/if}
		<div class="flex items-center gap-2">
			<span class="material-symbols-outlined text-[18px] text-on-surface-variant">group</span>
			{event.participantCount} / {event.maxParticipants} players
		</div>
	</div>

	<!-- Game tile -->
	{#if event.game}
		<div class="flex items-center gap-3 bg-surface-container-low rounded-xl p-3">
			{#if event.game.thumbnailUrl}
				<img src={event.game.thumbnailUrl} alt={event.game.title} class="w-12 h-12 object-cover rounded-lg" />
			{/if}
			<div>
				<p class="text-xs text-on-surface-variant font-label font-bold uppercase tracking-wide">Game</p>
				<p class="font-semibold text-sm">{event.game.title}</p>
			</div>
		</div>
	{/if}

	{#if event.description}
		<p class="text-sm text-on-surface">{event.description}</p>
	{/if}

	<!-- Host -->
	<div class="flex items-center gap-2">
		<Avatar src={event.host.avatarUrl} name={event.host.displayName ?? event.host.username} size="xs" />
		<p class="text-xs text-on-surface-variant">
			Hosted by <span class="font-semibold text-on-surface">{event.host.displayName ?? event.host.username}</span>
		</p>
	</div>
</div>

<!-- Actions -->
{#if !isHost && event.status !== 'CANCELLED'}
	<div class="space-y-2">
		{#if event.myRsvp === 'ACCEPTED'}
			<p class="text-sm font-semibold text-tertiary text-center">✓ You're going</p>
			<Button variant="secondary" fullWidth {loading} onclick={leave}>Leave Event</Button>
		{:else}
			<Button fullWidth {loading} onclick={() => rsvp('ACCEPTED')} disabled={event.status === 'FULL'}>
				{event.status === 'FULL' ? 'Event Full' : 'Join Event'}
			</Button>
			{#if event.myRsvp === 'INVITED'}
				<Button variant="secondary" fullWidth {loading} onclick={() => rsvp('DECLINED')}>Decline</Button>
			{/if}
		{/if}
	</div>
{:else if isHost}
	<div class="flex gap-2">
		<a href="/events/{event.id}/edit" class="flex-1">
			<Button variant="secondary" fullWidth>Edit</Button>
		</a>
		<button
			onclick={deleteEvent}
			class="px-4 py-2.5 rounded-xl text-sm font-label font-bold text-error bg-error/10"
		>Delete</button>
	</div>
{/if}
