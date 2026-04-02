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

	// Calendar strip — 7 days starting from today
	const today = new Date();
	today.setHours(0, 0, 0, 0);

	const calendarDays = Array.from({ length: 7 }, (_, i) => {
		const d = new Date(today);
		d.setDate(today.getDate() + i);
		return d;
	});

	let selectedDay = $state(0);

	const eventDates = $derived(
		new Set(
			events.upcoming.map((e) => {
				const d = new Date(e.scheduledAt);
				d.setHours(0, 0, 0, 0);
				return d.toDateString();
			})
		)
	);

	function dayHasEvent(d: Date) {
		return eventDates.has(d.toDateString());
	}

	function formatTime(iso: string) {
		return new Date(iso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
	}

	function formatDate(iso: string) {
		return new Date(iso).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
	}

	async function rsvp(event: Event, status: 'ACCEPTED' | 'DECLINED') {
		try {
			const updated = await eventsApi.rsvp(event.id, status);
			events = {
				upcoming: events.upcoming.map((e) => (e.id === updated.id ? updated : e)),
				mine:
					status === 'ACCEPTED'
						? [...events.mine.filter((e) => e.id !== updated.id), updated]
						: events.mine.filter((e) => e.id !== updated.id)
			};
		} catch {
			toast.error('Could not update RSVP');
		}
	}
</script>

<svelte:head><title>Events — Meeple</title></svelte:head>

<!-- Page title -->
<section class="mb-6 space-y-1">
	<h2 class="text-3xl font-headline font-extrabold tracking-tight">Game Nights</h2>
	<p class="text-on-surface-variant text-sm">Find your next adventure at a table near you.</p>
</section>

<!-- Calendar strip -->
<section class="mb-6">
	<div class="flex gap-3 overflow-x-auto hide-scrollbar -mx-4 px-4 pb-2">
		{#each calendarDays as day, i}
			{@const isSelected = selectedDay === i}
			{@const hasEvent = dayHasEvent(day)}
			<button
				onclick={() => (selectedDay = i)}
				class="flex-shrink-0 w-16 h-24 rounded-xl flex flex-col items-center justify-center gap-1 transition-all spring-bounce
					{isSelected
						? 'bg-primary-container text-on-primary-container shadow-lg scale-105'
						: 'bg-surface-container-lowest text-on-surface hover:bg-surface-container-low'}"
			>
				<span class="text-[10px] font-label font-bold uppercase tracking-widest opacity-80">
					{day.toLocaleDateString('en-US', { weekday: 'short' })}
				</span>
				<span class="text-2xl font-extrabold font-headline">{day.getDate()}</span>
				{#if hasEvent}
					<div class="w-1.5 h-1.5 rounded-full {isSelected ? 'bg-on-primary-container' : 'bg-primary opacity-60'}"></div>
				{:else}
					<div class="w-1.5 h-1.5"></div>
				{/if}
			</button>
		{/each}
	</div>
</section>

<!-- Tabs -->
<div class="flex items-center justify-between mb-6">
	<div class="flex gap-2">
		<button
			onclick={() => (tab = 'upcoming')}
			class="px-4 py-2 rounded-full text-sm font-label font-bold transition-colors {tab === 'upcoming' ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
		>Upcoming</button>
		<button
			onclick={() => (tab = 'mine')}
			class="px-4 py-2 rounded-full text-sm font-label font-bold transition-colors {tab === 'mine' ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
		>My Events</button>
	</div>
	{#if tab === 'upcoming'}
		<span class="text-sm font-label font-medium text-primary">{displayed.length} found</span>
	{/if}
</div>

<!-- Event list -->
{#if displayed.length === 0}
	<div class="text-center py-16 text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl mb-3 block opacity-40">event</span>
		<p class="font-semibold">No events yet</p>
		<p class="text-sm mt-1">Create one or check back later!</p>
	</div>
{:else}
	<div class="space-y-4">
		{#each displayed as event (event.id)}
			<a
				href="/events/{event.id}"
				class="group block bg-surface-container-lowest rounded-xl shadow-sm hover:shadow-md transition-all overflow-hidden"
			>
				<div class="flex gap-4 p-4">
					<!-- Game image or date block -->
					{#if event.game?.thumbnailUrl}
						<div class="w-20 h-20 rounded-lg overflow-hidden flex-shrink-0">
							<img
								src={event.game.thumbnailUrl}
								alt={event.game.title}
								class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
							/>
						</div>
					{:else}
						<div class="w-20 h-20 flex-shrink-0 bg-primary/10 rounded-lg flex flex-col items-center justify-center">
							<p class="text-[10px] font-label font-bold uppercase text-primary">
								{new Date(event.scheduledAt).toLocaleDateString('en-US', { month: 'short' })}
							</p>
							<p class="text-2xl font-extrabold font-headline text-primary leading-none">
								{new Date(event.scheduledAt).getDate()}
							</p>
						</div>
					{/if}

					<!-- Details -->
					<div class="flex-1 min-w-0">
						<div class="flex items-start justify-between gap-2 mb-1">
							<p class="font-bold text-on-surface line-clamp-1 flex-1">{event.title}</p>
							<span class="flex-shrink-0 text-[10px] font-label font-bold px-2 py-0.5 rounded-full
								{event.status === 'FULL' ? 'bg-error-container text-error' :
								 event.status === 'OPEN' ? 'bg-tertiary-container/30 text-on-tertiary-container' :
								 'bg-surface-container text-on-surface-variant'}">
								{event.status}
							</span>
						</div>

						<!-- Stats grid -->
						<div class="grid grid-cols-2 gap-x-4 gap-y-1 mt-2">
							<div class="flex items-center gap-1 text-[11px] text-on-surface-variant">
								<span class="material-symbols-outlined text-[13px]">person</span>
								<span class="truncate">{event.host.displayName ?? event.host.username}</span>
							</div>
							<div class="flex items-center gap-1 text-[11px] text-on-surface-variant">
								<span class="material-symbols-outlined text-[13px]">group</span>
								<span>{event.participantCount}/{event.maxParticipants}</span>
							</div>
							<div class="flex items-center gap-1 text-[11px] text-on-surface-variant">
								<span class="material-symbols-outlined text-[13px]">schedule</span>
								<span>{formatTime(event.scheduledAt)}</span>
							</div>
							{#if event.location}
								<div class="flex items-center gap-1 text-[11px] text-on-surface-variant">
									<span class="material-symbols-outlined text-[13px]">location_on</span>
									<span class="truncate">{event.location}</span>
								</div>
							{/if}
						</div>
					</div>
				</div>

				<!-- RSVP buttons -->
				{#if event.myRsvp !== 'ACCEPTED' && event.status !== 'CANCELLED'}
					<div class="flex gap-2 px-4 pb-4" onclick={(e) => e.preventDefault()}>
						<button
							onclick={() => rsvp(event, 'ACCEPTED')}
							disabled={event.status === 'FULL' && event.myRsvp !== 'ACCEPTED'}
							class="flex-1 py-2 rounded-xl text-sm font-label font-bold bg-primary text-on-primary disabled:opacity-40 transition-colors"
						>Join</button>
						{#if event.myRsvp === 'INVITED'}
							<button
								onclick={() => rsvp(event, 'DECLINED')}
								class="flex-1 py-2 rounded-xl text-sm font-label font-bold bg-surface-container-high text-on-surface-variant"
							>Decline</button>
						{/if}
					</div>
				{:else if event.myRsvp === 'ACCEPTED'}
					<p class="px-4 pb-4 text-xs font-label font-bold text-tertiary flex items-center gap-1">
						<span class="material-symbols-outlined text-[14px]" style="font-variation-settings: 'FILL' 1;">check_circle</span>
						You're going
					</p>
				{/if}
			</a>
		{/each}
	</div>
{/if}
