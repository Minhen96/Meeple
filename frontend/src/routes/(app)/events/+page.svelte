<script lang="ts">
	import type { PageData } from './$types';
	import type { Event } from '$lib/types';
	import { eventsApi } from '$lib/api/events';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { toast } from 'svelte-sonner';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	let tab = $state<'upcoming' | 'mine'>('upcoming');
	let events = $state({ upcoming: data.upcoming, mine: data.mine });

	const displayed = $derived(tab === 'upcoming' ? events.upcoming : events.mine);

	function formatDate(iso: string) {
		const d = new Date(iso);
		return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
	}

	function formatTime(iso: string) {
		return new Date(iso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
	}

	async function rsvp(event: Event, status: 'ACCEPTED' | 'DECLINED') {
		try {
			const updated = await eventsApi.rsvp(event.id, status);
			events = {
				upcoming: events.upcoming.map((e) => (e.id === updated.id ? updated : e)),
				mine: status === 'ACCEPTED'
					? [...events.mine.filter((e) => e.id !== updated.id), updated]
					: events.mine.filter((e) => e.id !== updated.id)
			};
		} catch {
			toast.error('Could not update RSVP');
		}
	}

	function statusColor(status: Event['status']) {
		return status === 'FULL' ? 'text-error' : status === 'OPEN' ? 'text-tertiary' : 'text-on-surface-variant';
	}
</script>

<svelte:head><title>Events — Meeple & Hearth</title></svelte:head>

<!-- Tabs -->
<div class="flex items-center justify-between mb-4">
	<div class="flex gap-2">
		<button
			onclick={() => (tab = 'upcoming')}
			class="px-4 py-2 rounded-full text-sm font-label font-bold {tab === 'upcoming' ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
		>Upcoming</button>
		<button
			onclick={() => (tab = 'mine')}
			class="px-4 py-2 rounded-full text-sm font-label font-bold {tab === 'mine' ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
		>My Events</button>
	</div>
</div>

{#if displayed.length === 0}
	<div class="text-center py-16 text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl mb-3 block opacity-40">event</span>
		<p class="font-semibold">No events yet</p>
		<p class="text-sm mt-1">Create one or check back later!</p>
	</div>
{:else}
	<div class="space-y-4">
		{#each displayed as event (event.id)}
			<a href="/events/{event.id}" class="block bg-surface-container-lowest rounded-xl p-4 shadow-[0_12px_32px_rgba(25,28,29,0.06)] space-y-3">
				<!-- Date + title -->
				<div class="flex gap-3">
					<div class="flex-shrink-0 w-14 text-center bg-primary/10 rounded-xl py-2">
						<p class="text-[10px] font-label font-bold uppercase text-primary">
							{new Date(event.scheduledAt).toLocaleDateString('en-US', { month: 'short' })}
						</p>
						<p class="text-2xl font-extrabold font-headline text-primary leading-none">
							{new Date(event.scheduledAt).getDate()}
						</p>
					</div>
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-on-surface line-clamp-1">{event.title}</p>
						<p class="text-xs text-on-surface-variant mt-0.5">
							{formatTime(event.scheduledAt)}{event.location ? ` · ${event.location}` : ''}
						</p>
						<div class="flex items-center gap-2 mt-1.5">
							<span class="text-xs font-semibold {statusColor(event.status)}">{event.status}</span>
							<span class="text-xs text-on-surface-variant">
								{event.participantCount}/{event.maxParticipants} players
							</span>
						</div>
					</div>
				</div>

				<!-- Host -->
				<div class="flex items-center gap-2">
					<Avatar src={event.host.avatarUrl} name={event.host.displayName ?? event.host.username} size="xs" />
					<p class="text-xs text-on-surface-variant">
						Hosted by <span class="font-semibold text-on-surface">{event.host.displayName ?? event.host.username}</span>
					</p>
				</div>

				<!-- RSVP buttons (only if not already accepted as host) -->
				{#if event.myRsvp !== 'ACCEPTED' && event.status !== 'CANCELLED'}
					<div class="flex gap-2 pt-1" onclick={(e) => e.preventDefault()}>
						<button
							onclick={() => rsvp(event, 'ACCEPTED')}
							disabled={event.status === 'FULL' && event.myRsvp !== 'ACCEPTED'}
							class="flex-1 py-2 rounded-xl text-sm font-label font-bold bg-primary text-on-primary disabled:opacity-40"
						>Join</button>
						{#if event.myRsvp === 'INVITED'}
							<button
								onclick={() => rsvp(event, 'DECLINED')}
								class="flex-1 py-2 rounded-xl text-sm font-label font-bold bg-surface-container-high text-on-surface-variant"
							>Decline</button>
						{/if}
					</div>
				{:else if event.myRsvp === 'ACCEPTED'}
					<p class="text-xs font-semibold text-tertiary">✓ You're going</p>
				{/if}
			</a>
		{/each}
	</div>
{/if}

<!-- FAB -->
<a href="/events/create" class="fixed bottom-24 right-4 w-14 h-14 bg-gradient-to-br from-primary to-primary-container rounded-full flex items-center justify-center shadow-[0_8px_24px_rgba(137,81,0,0.30)] hover:scale-110 active:scale-95 transition-all z-40">
	<span class="material-symbols-outlined text-on-primary text-2xl">add</span>
</a>
