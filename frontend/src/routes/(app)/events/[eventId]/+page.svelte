<script lang="ts">
	import type { PageData } from './$types';
	import { eventsApi } from '$lib/api/events';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import { toast } from 'svelte-sonner';
	import { goto } from '$app/navigation';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import { fade, fly, scale } from 'svelte/transition';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let event = $state(data.event);
	$effect(() => {
		event = data.event;
	});
	let loading = $state(false);
	let showDeleteConfirm = $state(false);

	const isHost = $derived(data.user?.id === event.host.id);

	function formatDateTime(iso: string) {
		const date = new Date(iso);
		return {
			full: date.toLocaleString('en-US', {
				weekday: 'long', month: 'long', day: 'numeric',
				hour: 'numeric', minute: '2-digit'
			}),
			day: date.getDate(),
			month: date.toLocaleString('en-US', { month: 'short' }),
			time: date.toLocaleString('en-US', { hour: 'numeric', minute: '2-digit' })
		};
	}

	const dt = $derived(formatDateTime(event.scheduledAt));

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
		showDeleteConfirm = false;
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

{#if showDeleteConfirm}
	<ConfirmDialog
		title="Delete Event"
		message="Are you sure you want to delete this event? This cannot be undone."
		confirmLabel="Delete"
		danger={true}
		onConfirm={deleteEvent}
		onCancel={() => (showDeleteConfirm = false)}
	/>
{/if}

<div class="relative min-h-screen pb-32">
	<!-- Hero Section -->
	<div class="relative h-64 w-full overflow-hidden">
		<!-- Background Art / Gradient -->
		<div class="absolute inset-0 bg-gradient-to-br from-primary/80 via-secondary/70 to-tertiary/60"></div>
		{#if event.game?.thumbnailUrl}
			<img 
				src={event.game.thumbnailUrl} 
				alt="" 
				class="absolute inset-0 w-full h-full object-cover mix-blend-overlay blur-[2px] scale-110 opacity-40"
			/>
		{/if}
		
		<!-- Back Button -->
		<div class="absolute top-4 left-4 z-20">
			<button
				onclick={() => history.back()}
				class="w-11 h-11 rounded-2xl bg-white/20 backdrop-blur-xl border border-white/20 flex items-center justify-center text-white hover:bg-white/30 transition-all active:scale-90 shadow-lg"
				aria-label="Back"
			>
				<span class="material-symbols-outlined text-[24px]">arrow_back</span>
			</button>
		</div>

		<!-- Title Overlay -->
		<div class="absolute bottom-0 left-0 right-0 p-6 bg-gradient-to-t from-black/60 to-transparent">
			<div in:fly={{ y: 20, duration: 500 }}>
				<div class="flex items-center gap-2 mb-2">
					<span class="px-2.5 py-0.5 rounded-full bg-white/20 backdrop-blur-md text-[10px] font-black uppercase tracking-widest text-white border border-white/10">
						{event.status}
					</span>
					{#if event.visibility !== 'PUBLIC'}
						<span class="material-symbols-outlined text-white/70 text-[14px]">
							{event.visibility === 'FRIENDS' ? 'group' : 'lock'}
						</span>
					{/if}
				</div>
				<h1 class="text-3xl font-black font-headline text-white leading-tight drop-shadow-md">
					{event.title}
				</h1>
			</div>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="px-5 pt-6 space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
		
		<!-- Quick Meta Bento -->
		<div class="grid grid-cols-2 gap-3">
			<div class="bg-surface-container-low rounded-3xl p-5 border border-outline-variant/10 flex flex-col gap-3">
				<div class="w-10 h-10 rounded-2xl bg-primary/10 flex items-center justify-center text-primary">
					<span class="material-symbols-outlined text-[22px]">calendar_today</span>
				</div>
				<div>
					<p class="text-[10px] font-black uppercase tracking-widest text-on-surface-variant/60 mb-0.5">When</p>
					<p class="text-sm font-bold font-headline leading-tight">{dt.full}</p>
				</div>
			</div>
			<div class="bg-surface-container-low rounded-3xl p-5 border border-outline-variant/10 flex flex-col gap-3">
				<div class="w-10 h-10 rounded-2xl bg-secondary/10 flex items-center justify-center text-secondary">
					<span class="material-symbols-outlined text-[22px]">location_on</span>
				</div>
				<div>
					<p class="text-[10px] font-black uppercase tracking-widest text-on-surface-variant/60 mb-0.5">Where</p>
					<p class="text-sm font-bold font-headline leading-tight truncate">{event.location || 'Wait for coordinates'}</p>
				</div>
			</div>
		</div>

		<!-- Game & Description -->
		<div class="space-y-4">
			{#if event.game}
				<div class="group flex items-center gap-4 bg-on-surface/5 rounded-[2rem] p-4 border border-outline-variant/10 transition-all hover:bg-on-surface/[0.08]">
					<div class="relative w-16 h-16 flex-shrink-0">
						<img 
							src={event.game.thumbnailUrl || '/game-placeholder.png'} 
							alt={event.game.title} 
							class="w-full h-full object-cover rounded-2xl shadow-md group-hover:scale-105 transition-transform"
						/>
						<div class="absolute -top-1 -right-1 w-6 h-6 rounded-full bg-primary flex items-center justify-center text-white border-2 border-surface shadow-sm">
							<span class="material-symbols-outlined text-[14px]">casino</span>
						</div>
					</div>
					<div class="flex-1 min-w-0">
						<p class="text-[10px] font-black uppercase tracking-widest text-primary mb-0.5">Playing</p>
						<h3 class="font-black font-headline text-lg text-on-surface truncate">{event.game.title}</h3>
					</div>
					<span class="material-symbols-outlined text-on-surface-variant/30 px-2 group-hover:translate-x-1 transition-transform">chevron_right</span>
				</div>
			{/if}

			{#if event.description}
				<div class="relative px-1">
					<p class="text-base font-body text-on-surface/80 leading-relaxed italic">
						"{event.description}"
					</p>
				</div>
			{/if}
		</div>

		<!-- Participants Section -->
		<div class="space-y-4">
			<div class="flex items-center justify-between px-1">
				<div class="flex flex-col">
					<h3 class="text-sm font-black font-headline text-on-surface uppercase tracking-wider">Party Roster</h3>
					<p class="text-[11px] text-on-surface-variant/60 font-medium">
						{event.participantCount} joined • {event.maxParticipants - event.participantCount} spots left
					</p>
				</div>
				<!-- Progress ring or bar simplified -->
				<div class="h-1.5 w-24 bg-surface-container-highest rounded-full overflow-hidden">
					<div class="h-full bg-secondary transition-all duration-1000" style="width: {(event.participantCount / event.maxParticipants) * 100}%"></div>
				</div>
			</div>

			<div class="bg-surface-container-low rounded-3xl p-5 border border-outline-variant/10">
				<!-- Host -->
				<div class="flex items-center justify-between mb-6 pb-4 border-b border-outline-variant/10">
					<div class="flex items-center gap-3">
						<div class="relative">
							<Avatar src={event.host.avatarUrl} name={event.host.displayName ?? event.host.username} size="sm" className="ring-2 ring-primary/20" />
							<div class="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-primary flex items-center justify-center text-white border-2 border-surface shadow-sm">
								<span class="material-symbols-outlined text-[12px]">crown</span>
							</div>
						</div>
						<div>
							<p class="text-xs font-black font-headline text-on-surface">{event.host.displayName ?? event.host.username}</p>
							<p class="text-[10px] font-bold text-primary uppercase tracking-tighter">Event Host</p>
						</div>
					</div>
					<button class="px-3 py-1.5 rounded-xl bg-surface-container-high text-[10px] font-black uppercase text-on-surface-variant hover:bg-primary/10 hover:text-primary transition-colors">
						View Profile
					</button>
				</div>

				<!-- Other participants placeholder or list -->
				<div class="flex flex-wrap gap-2">
					<!-- In a real app we'd map players here. Using a placeholder for now since limited in data -->
					<div class="flex -space-x-3 overflow-hidden p-1">
						<Avatar src={event.host.avatarUrl} name="Player" size="xs" className="ring-4 ring-surface" />
						<div class="w-8 h-8 rounded-full bg-surface-container-highest ring-4 ring-surface flex items-center justify-center text-[10px] font-black text-on-surface-variant">
							+{event.participantCount - 1}
						</div>
					</div>
					<p class="text-xs text-on-surface-variant/70 italic flex items-center">
						joining this mission
					</p>
				</div>
			</div>
		</div>

		<!-- Host Controls (secondary position) -->
		{#if isHost}
			<div class="flex gap-2">
				<a href="/events/{event.id}/edit" class="flex-1">
					<Button variant="secondary" fullWidth className="rounded-2xl border-outline-variant/30">Edit Details</Button>
				</a>
				<button
					onclick={() => (showDeleteConfirm = true)}
					class="w-12 h-11 rounded-2xl bg-error/10 text-error flex items-center justify-center hover:bg-error hover:text-white transition-all active:scale-90"
					aria-label="Delete Event"
				>
					<span class="material-symbols-outlined">delete</span>
				</button>
			</div>
		{/if}
	</div>

	<!-- Sticky RSVP Bar -->
	{#if !isHost && event.status !== 'CANCELLED'}
		<div class="fixed bottom-24 left-4 right-4 z-30 max-w-2xl mx-auto">
			<div class="bg-surface-container/60 backdrop-blur-3xl rounded-[2.5rem] p-2 border border-white/10 shadow-[0_20px_50px_rgba(0,0,0,0.2)] flex items-center gap-2">
				{#if event.myRsvp === 'ACCEPTED'}
					<div class="flex-1 flex items-center gap-3 px-4 py-3 bg-tertiary/10 rounded-3xl">
						<div class="w-8 h-8 rounded-full bg-tertiary text-white flex items-center justify-center" in:scale>
							<span class="material-symbols-outlined text-[18px]">done_all</span>
						</div>
						<div>
							<p class="text-xs font-black font-headline text-tertiary uppercase">You're confirmed</p>
							<p class="text-[10px] text-tertiary/70 font-medium">Preparing for takeoff</p>
						</div>
					</div>
					<button
						onclick={leave}
						disabled={loading}
						class="w-12 h-12 rounded-3xl bg-surface-container-highest flex items-center justify-center text-on-surface-variant hover:bg-error/10 hover:text-error transition-all"
						aria-label="Leave Event"
					>
						<span class="material-symbols-outlined">logout</span>
					</button>
				{:else}
					<button
						onclick={() => rsvp('ACCEPTED')}
						disabled={loading || event.status === 'FULL'}
						class="flex-1 py-4 bg-on-surface text-surface rounded-[2rem] font-black font-headline text-base shadow-lg hover:scale-[1.02] active:scale-95 transition-all overflow-hidden relative group"
					>
						<div class="absolute inset-0 bg-gradient-to-r from-primary to-secondary opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
						<span class="relative z-10">{event.status === 'FULL' ? 'Join Waitlist' : 'Join Mission'}</span>
					</button>
					{#if event.myRsvp === 'INVITED'}
						<button
							onclick={() => rsvp('DECLINED')}
							disabled={loading}
							class="w-14 h-14 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface hover:bg-error/10 hover:text-error transition-all"
							aria-label="Decline Invitation"
						>
							<span class="material-symbols-outlined">close</span>
						</button>
					{/if}
				{/if}
			</div>
		</div>
	{/if}
</div>
