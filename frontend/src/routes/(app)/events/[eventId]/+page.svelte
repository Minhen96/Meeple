<script lang="ts">
	import { onDestroy, untrack } from 'svelte';
	import { fly } from 'svelte/transition';
	import { toast } from 'svelte-sonner';
	import { eventsApi } from '$lib/api/events';
	import { getLocale, m } from '$lib/i18n';
	import { subscribeTopic } from '$lib/stores/websocket';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ProgressBar from '$lib/components/ui/ProgressBar.svelte';
	import PostCard from '$lib/components/social/PostCard.svelte';
	import BottomSheet from '$lib/components/event/BottomSheet.svelte';
	import FriendPicker from '$lib/components/event/FriendPicker.svelte';
	import {
		displayName,
		eventErrorMessage,
		formatEventDateTime,
		rsvpAction,
		rsvpLabel,
		statusChipClass,
		statusLabel
	} from '$lib/components/event/eventState';
	import type { Event as EventDetail, EventParticipant, Post } from '$lib/types';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const locale = getLocale();

	// Writable derived: follows load data, replaced after actions and live updates.
	let event = $derived(data.event);
	let busy = $state(false);
	let menuOpen = $state(false);
	let sheet = $state<'participants' | 'invite' | null>(null);
	let confirm = $state<'cancel' | 'leave' | { kick: EventParticipant } | null>(null);
	let inviteIds = $state<string[]>([]);
	let memories = $state<Post[] | null>(null);
	let memoriesError = $state(false);

	const action = $derived(rsvpAction(event));
	const others = $derived(event.participants.filter((p) => p.id !== event.host.id && p.status === 'ACCEPTED'));
	const managed = $derived(event.participants.filter((p) => p.id !== event.host.id));
	const spotsLeft = $derived(Math.max(0, event.maxParticipants - event.participantCount));
	const visibilityKey = $derived(
		event.visibility === 'PUBLIC'
			? 'event.detail.visibility.public'
			: event.visibility === 'FRIENDS'
				? 'event.detail.visibility.friends'
				: 'event.detail.visibility.inviteOnly'
	);
	const visibilityIcon = $derived(
		event.visibility === 'PUBLIC' ? 'public' : event.visibility === 'FRIENDS' ? 'group' : 'lock'
	);
	const pendingOrGoing = $derived(
		event.participants.filter((p) => p.status === 'INVITED' || p.status === 'ACCEPTED').map((p) => p.id)
	);

	/** The event this page shows; results of requests made for another event are dropped. */
	const currentId = $derived(data.event.id);

	/** Apply a server response, unless the page has moved on to another event meanwhile. */
	function apply(next: EventDetail) {
		if (next.id === currentId) event = next;
	}

	// ─── Live updates on /topic/events/{id}: refresh the viewer-specific view ──────
	let unsubscribe: (() => void) | null = null;
	let refreshTimer: ReturnType<typeof setTimeout> | undefined;
	let subscribedId: string | null = null;

	/** Id named by a live frame, if any (`{eventId, participantCount, status}`; older frames also carried participants). */
	function frameEventId(body: string): string | null {
		try {
			const value: unknown = JSON.parse(body);
			if (typeof value === 'object' && value !== null) {
				const id = (value as Record<string, unknown>).eventId;
				return typeof id === 'string' ? id : null;
			}
		} catch {
			// not JSON: still a change signal
		}
		return null;
	}

	// Switching to another event (same component, new data): drop everything that belonged to
	// the previous one, then follow the new event's topic.
	$effect.pre(() => {
		const id = currentId;
		if (id === subscribedId) return;
		untrack(() => {
			unsubscribe?.();
			clearTimeout(refreshTimer);
			if (subscribedId !== null) {
				memories = null;
				memoriesError = false;
				sheet = null;
				confirm = null;
				menuOpen = false;
				inviteIds = [];
			}
			subscribedId = id;
			// The payload is the same for every subscriber and carries no viewer-specific data;
			// re-fetch so participants, masking and block filtering stay correct for this viewer.
			// Bursts are coalesced.
			unsubscribe = subscribeTopic(`/topic/events/${id}`, (frame) => {
				const named = frameEventId(frame.body);
				if (named !== null && named !== id) return;
				clearTimeout(refreshTimer);
				refreshTimer = setTimeout(refresh, 300);
			});
		});
	});

	onDestroy(() => {
		unsubscribe?.();
		clearTimeout(refreshTimer);
	});

	async function refresh() {
		const id = currentId;
		try {
			apply(await eventsApi.getEvent(id));
		} catch {
			// Keep showing the last state; the next update or navigation retries
		}
	}

	async function run(task: () => Promise<void>) {
		busy = true;
		try {
			await task();
		} catch (err) {
			toast.error(eventErrorMessage(err));
		} finally {
			busy = false;
		}
	}

	const rsvp = (status: 'ACCEPTED' | 'DECLINED') =>
		run(async () => {
			apply(await eventsApi.rsvp(event.id, status));
			toast.success(status === 'ACCEPTED' ? m('event.toast.joined') : m('event.toast.declined'));
		});

	const leave = () =>
		run(async () => {
			confirm = null;
			await eventsApi.leaveEvent(event.id);
			toast.success(m('event.toast.left'));
			await refresh();
		});

	const cancelEvent = () =>
		run(async () => {
			confirm = null;
			await eventsApi.cancelEvent(event.id);
			toast.success(m('event.toast.cancelled'));
			await refresh();
		});

	const kick = (participant: EventParticipant) =>
		run(async () => {
			confirm = null;
			apply(await eventsApi.kick(event.id, participant.id));
			toast.success(m('event.toast.kicked', { name: displayName(participant) }));
		});

	const sendInvites = () =>
		run(async () => {
			if (inviteIds.length === 0) return;
			apply(await eventsApi.invite(event.id, inviteIds));
			inviteIds = [];
			sheet = null;
			toast.success(m('event.toast.invited'));
		});

	async function loadMemories() {
		const id = currentId;
		memoriesError = false;
		try {
			const items = (await eventsApi.getMemories(id)).items;
			if (id === currentId) memories = items;
		} catch {
			if (id !== currentId) return;
			memories = [];
			memoriesError = true;
		}
	}

	function openFromMenu(target: 'participants' | 'invite' | 'cancel') {
		menuOpen = false;
		if (target === 'cancel') confirm = 'cancel';
		else sheet = target;
	}
</script>

<svelte:head><title>{event.title} — Meeple</title></svelte:head>

{#if confirm === 'cancel'}
	<ConfirmDialog
		title={m('event.manage.cancelTitle')}
		message={m('event.manage.cancelBody')}
		confirmLabel={m('event.manage.cancelConfirm')}
		cancelLabel={m('event.manage.keep')}
		danger
		onConfirm={cancelEvent}
		onCancel={() => (confirm = null)}
	/>
{:else if confirm === 'leave'}
	<ConfirmDialog
		title={m('event.manage.leaveTitle')}
		message={m('event.manage.leaveBody')}
		confirmLabel={m('event.manage.leaveConfirm')}
		cancelLabel={m('event.manage.stay')}
		danger
		onConfirm={leave}
		onCancel={() => (confirm = null)}
	/>
{:else if confirm}
	{@const target = confirm.kick}
	<ConfirmDialog
		title={m('event.manage.kickTitle')}
		message={m('event.manage.kickBody', { name: displayName(target) })}
		confirmLabel={m('event.manage.kick')}
		cancelLabel={m('common.cancel')}
		danger
		onConfirm={() => kick(target)}
		onCancel={() => (confirm = null)}
	/>
{/if}

<div class="relative min-h-screen pb-40">
	<!-- Hero (DESIGN section 12) -->
	<div class="relative h-64 w-full overflow-hidden rounded-b-lg">
		<div class="absolute inset-0 bg-gradient-to-br from-primary/80 via-secondary/70 to-tertiary/60"></div>
		{#if event.game?.thumbnailUrl}
			<img
				src={event.game.thumbnailUrl}
				alt=""
				class="absolute inset-0 w-full h-full object-cover mix-blend-overlay blur-[2px] scale-110 opacity-40"
			/>
		{/if}
		<div class="absolute top-4 left-4 z-20">
			<button
				type="button"
				onclick={() => history.back()}
				class="w-11 h-11 rounded-full bg-white/20 backdrop-blur-xl border border-white/10 flex items-center justify-center text-on-primary hover:bg-white/30 transition-all spring-bounce"
				aria-label={m('event.detail.back')}
			>
				<span class="material-symbols-outlined text-[24px]" aria-hidden="true">arrow_back</span>
			</button>
		</div>
		<div class="absolute bottom-0 left-0 right-0 p-6 bg-gradient-to-t from-black/60 to-transparent">
			<div in:fly={{ y: 20, duration: 400 }}>
				<div class="flex items-center gap-2 mb-2">
					<span class="px-3 py-1 rounded-full text-xs font-bold font-label {statusChipClass(event.status)}">
						{statusLabel(event.status)}
					</span>
					<span class="flex items-center gap-1 text-[11px] font-label font-bold text-on-primary/80">
						<span class="material-symbols-outlined text-[14px]" aria-hidden="true">{visibilityIcon}</span>
						{m(visibilityKey)}
					</span>
				</div>
				<h1 class="text-3xl font-black font-headline text-on-primary leading-tight drop-shadow-md">{event.title}</h1>
			</div>
		</div>
	</div>

	<div class="px-1 pt-6 space-y-6">
		{#if action === 'cancelled'}
			<p class="rounded-lg bg-error-container text-on-error-container px-4 py-3 text-sm font-bold" role="status">
				{m('event.detail.cancelledBanner')}
			</p>
		{:else if action === 'completed'}
			<div class="rounded-lg bg-surface-container-high px-4 py-3 flex items-center justify-between gap-3" role="status">
				<p class="text-sm font-bold text-on-surface">{m('event.detail.completedBanner')}</p>
				<button
					type="button"
					onclick={loadMemories}
					class="px-4 py-2 rounded-full bg-primary text-on-primary text-xs font-label font-bold spring-bounce"
				>
					{m('event.detail.viewMemories')}
				</button>
			</div>
		{:else if action === 'kicked'}
			<p class="rounded-lg bg-surface-container-high px-4 py-3 text-sm text-on-surface-variant" role="status">
				{m('event.detail.kickedNotice')}
			</p>
		{/if}

		<!-- Host row (not linked when the host's account was deleted) -->
		{#if event.host.deleted}
			<div class="flex items-center gap-3 p-3 rounded-lg bg-surface-container-low">
			<Avatar src={event.host.avatarUrl} name={displayName(event.host)} size="md" />
			<div class="flex-1 min-w-0">
				<p class="text-sm font-bold font-headline text-on-surface truncate">
					{m('event.detail.hostedBy', { name: displayName(event.host) })}
				</p>
				<p class="text-[10px] font-bold text-primary uppercase tracking-widest">{m('event.detail.host')}</p>
			</div>
			</div>
		{:else}
			<a
				href="/profile/{event.host.id}"
				class="flex items-center gap-3 p-3 rounded-lg bg-surface-container-low hover:bg-surface-container transition-colors"
			>
			<Avatar src={event.host.avatarUrl} name={displayName(event.host)} size="md" />
			<div class="flex-1 min-w-0">
				<p class="text-sm font-bold font-headline text-on-surface truncate">
					{m('event.detail.hostedBy', { name: displayName(event.host) })}
				</p>
				<p class="text-[10px] font-bold text-primary uppercase tracking-widest">{m('event.detail.host')}</p>
			</div>
				<span class="material-symbols-outlined text-on-surface-variant" aria-hidden="true">chevron_right</span>
			</a>
		{/if}

		<!-- Info cards -->
		<div class="grid grid-cols-2 gap-3">
			<div class="bg-surface-container-low rounded-lg p-4 flex flex-col gap-2">
				<span class="material-symbols-outlined text-primary" aria-hidden="true">calendar_today</span>
				<p class="text-[10px] font-black uppercase tracking-widest text-on-surface-variant">{m('event.detail.when')}</p>
				<p class="text-sm font-bold font-headline leading-tight">{formatEventDateTime(event.scheduledAt, locale)}</p>
			</div>
			<div class="bg-surface-container-low rounded-lg p-4 flex flex-col gap-2">
				<span class="material-symbols-outlined text-secondary" aria-hidden="true">location_on</span>
				<p class="text-[10px] font-black uppercase tracking-widest text-on-surface-variant">{m('event.detail.where')}</p>
				{#if event.location}
					<p class="text-sm font-bold font-headline leading-tight break-words">{event.location}</p>
				{:else if event.locationDisplay}
					<p class="text-sm font-bold font-headline leading-tight break-words">{event.locationDisplay}</p>
					<p class="text-[11px] text-on-surface-variant">{m('event.detail.locationHidden')}</p>
				{:else}
					<p class="text-sm font-bold font-headline leading-tight text-on-surface-variant">{m('event.detail.locationTbd')}</p>
				{/if}
			</div>
		</div>

		{#if event.game}
			<a
				href="/library/{event.game.id}"
				class="flex items-center gap-4 bg-surface-container-low rounded-lg p-4 hover:bg-surface-container transition-colors"
			>
				{#if event.game.thumbnailUrl}
					<img src={event.game.thumbnailUrl} alt="" class="w-14 h-14 object-cover rounded-lg" />
				{/if}
				<div class="flex-1 min-w-0">
					<p class="text-[10px] font-black uppercase tracking-widest text-primary">{m('event.detail.playing')}</p>
					<p class="font-black font-headline text-lg text-on-surface truncate">{event.game.title}</p>
				</div>
				<span class="material-symbols-outlined text-on-surface-variant" aria-hidden="true">chevron_right</span>
			</a>
		{/if}

		{#if event.description}
			<p class="px-1 text-base font-body text-on-surface leading-relaxed whitespace-pre-line">{event.description}</p>
		{/if}

		<!-- Participants -->
		<section class="space-y-3" aria-labelledby="participants-heading">
			<div class="flex items-center justify-between px-1">
				<div>
					<h3 id="participants-heading" class="text-sm font-black font-headline uppercase tracking-wider">
						{m('event.detail.players')}
					</h3>
					<p class="text-[11px] text-on-surface-variant">
						{m('event.detail.spots', { count: event.participantCount, left: spotsLeft })}
					</p>
				</div>
				<ProgressBar
					value={event.participantCount}
					max={event.maxParticipants}
					tone="secondary"
					track="highest"
					class="h-1.5 w-24"
					label={m('event.detail.spotsFilled')}
				/>
			</div>
			<div class="bg-surface-container-low rounded-lg p-4">
				{#if others.length === 0}
					<p class="text-sm text-on-surface-variant">{m('event.detail.noOneYet')}</p>
				{:else}
					<ul class="grid grid-cols-4 sm:grid-cols-6 gap-3">
						{#each others as p (p.id)}
							<li>
								<a href="/profile/{p.id}" class="flex flex-col items-center gap-1 text-center">
									<Avatar src={p.avatarUrl} name={displayName(p)} size="lg" />
									<span class="text-[11px] font-bold text-on-surface truncate w-full">{displayName(p)}</span>
								</a>
							</li>
						{/each}
					</ul>
				{/if}
			</div>
		</section>

		{#if memories !== null}
			<section class="space-y-3" aria-labelledby="memories-heading">
				<div class="flex items-center justify-between px-1">
					<h3 id="memories-heading" class="text-sm font-black font-headline uppercase tracking-wider">
						{m('event.detail.memoriesTitle')}
					</h3>
					<a href="/posts/create?eventId={event.id}" class="text-xs font-label font-bold text-primary">
						{m('event.detail.shareMemory')}
					</a>
				</div>
				{#if memoriesError}
					<p class="text-sm text-on-surface-variant px-1">{m('event.detail.memoriesError')}</p>
				{:else if memories.length === 0}
					<p class="text-sm text-on-surface-variant px-1">{m('event.detail.noMemories')}</p>
				{:else}
					{#each memories as post (post.id)}
						<PostCard {post} />
					{/each}
				{/if}
			</section>
		{/if}
	</div>

	<!-- Action bar (SCREENS section 6.4) -->
	{#if action !== 'cancelled' && action !== 'completed' && action !== 'none' && action !== 'kicked'}
		<div class="fixed bottom-24 left-4 right-4 z-30 max-w-2xl mx-auto">
			<div class="relative bg-surface/80 backdrop-blur-xl rounded-full p-2 border border-white/10 shadow-lg flex items-center gap-2">
				{#if action === 'host'}
					<button
						type="button"
						onclick={() => (menuOpen = !menuOpen)}
						aria-haspopup="menu"
						aria-expanded={menuOpen}
						class="flex-1 py-3 rounded-full bg-on-surface text-surface font-headline font-black flex items-center justify-center gap-2 spring-bounce"
					>
						<span class="material-symbols-outlined text-[20px]" aria-hidden="true">tune</span>
						{m('event.action.manage')}
					</button>
					{#if menuOpen}
						<div
							role="menu"
							class="absolute bottom-full mb-2 left-0 right-0 bg-surface/90 backdrop-blur-xl border border-white/10 rounded-lg shadow-2xl p-2"
							transition:fly={{ y: 10, duration: 150 }}
						>
							<a role="menuitem" href="/events/{event.id}/edit" class="flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-surface-container-high text-sm font-bold">
								<span class="material-symbols-outlined text-[20px]" aria-hidden="true">edit</span>
								{m('event.manage.edit')}
							</a>
							<button role="menuitem" type="button" onclick={() => openFromMenu('invite')} class="w-full flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-surface-container-high text-sm font-bold">
								<span class="material-symbols-outlined text-[20px]" aria-hidden="true">person_add</span>
								{m('event.manage.invite')}
							</button>
							<button role="menuitem" type="button" onclick={() => openFromMenu('participants')} class="w-full flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-surface-container-high text-sm font-bold">
								<span class="material-symbols-outlined text-[20px]" aria-hidden="true">groups</span>
								{m('event.manage.participants')}
							</button>
							<button role="menuitem" type="button" onclick={() => openFromMenu('cancel')} class="w-full flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-error-container text-sm font-bold text-error">
								<span class="material-symbols-outlined text-[20px]" aria-hidden="true">event_busy</span>
								{m('event.manage.cancel')}
							</button>
						</div>
					{/if}
				{:else if action === 'going'}
					<p class="flex-1 px-4 text-sm font-black font-headline text-tertiary flex items-center gap-2">
						<span class="icon-filled material-symbols-outlined text-[20px]" aria-hidden="true">check_circle</span>
						{m('event.card.going')}
					</p>
					<button
						type="button"
						onclick={() => (confirm = 'leave')}
						disabled={busy}
						class="px-5 py-3 rounded-full bg-surface-container-highest text-on-surface-variant text-sm font-label font-bold hover:bg-error-container hover:text-on-error-container transition-colors disabled:opacity-50"
					>
						{m('event.action.leave')}
					</button>
				{:else if action === 'respond'}
					<button
						type="button"
						onclick={() => rsvp('ACCEPTED')}
						disabled={busy || event.status === 'FULL'}
						class="flex-1 py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-headline font-bold disabled:opacity-50 spring-bounce"
					>
						{event.status === 'FULL' ? m('event.action.full') : m('event.action.accept')}
					</button>
					<button
						type="button"
						onclick={() => rsvp('DECLINED')}
						disabled={busy}
						class="px-5 py-3 rounded-full bg-surface-container-high text-on-surface text-sm font-label font-bold disabled:opacity-50 spring-bounce"
					>
						{m('event.action.decline')}
					</button>
				{:else if action === 'changeToGoing' || action === 'join'}
					<button
						type="button"
						onclick={() => rsvp('ACCEPTED')}
						disabled={busy}
						class="flex-1 py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-headline font-bold disabled:opacity-50 spring-bounce"
					>
						{action === 'join' ? m('event.action.join') : m('event.action.changeToGoing')}
					</button>
				{:else if action === 'full'}
					<button type="button" disabled class="flex-1 py-3 rounded-full bg-surface-container-highest text-on-surface-variant font-headline font-bold">
						{m('event.action.full')}
					</button>
				{/if}
			</div>
		</div>
	{:else if action === 'none' && event.status !== 'CANCELLED' && event.status !== 'COMPLETED'}
		<p class="mt-6 text-center text-sm text-on-surface-variant">{m('event.detail.inviteOnlyNotice')}</p>
	{/if}
</div>

{#if sheet === 'participants'}
	<BottomSheet title={m('event.manage.participantsTitle')} onClose={() => (sheet = null)}>
		{#if managed.length === 0}
			<p class="text-sm text-on-surface-variant py-4">{m('event.detail.noOneYet')}</p>
		{:else}
			<ul class="space-y-2">
				{#each managed as p (p.id)}
					<li class="flex items-center gap-3 p-2 rounded-lg bg-surface-container-low">
						<Avatar src={p.avatarUrl} name={displayName(p)} size="sm" />
						<div class="flex-1 min-w-0">
							<p class="text-sm font-bold truncate">{displayName(p)}</p>
							<p class="text-[11px] text-on-surface-variant">{rsvpLabel(p.status)}</p>
						</div>
						{#if p.status === 'ACCEPTED' || p.status === 'INVITED'}
							<button
								type="button"
								onclick={() => (confirm = { kick: p })}
								disabled={busy}
								class="px-3 py-1.5 rounded-full bg-error-container text-on-error-container text-xs font-label font-bold disabled:opacity-50"
								aria-label={m('event.manage.kickLabel', { name: displayName(p) })}
							>
								{m('event.manage.kick')}
							</button>
						{/if}
					</li>
				{/each}
			</ul>
		{/if}
	</BottomSheet>
{:else if sheet === 'invite'}
	<BottomSheet title={m('event.manage.inviteTitle')} onClose={() => (sheet = null)}>
		<FriendPicker bind:selected={inviteIds} excludeIds={pendingOrGoing} />
		<button
			type="button"
			onclick={sendInvites}
			disabled={busy || inviteIds.length === 0}
			class="mt-4 w-full py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-headline font-bold disabled:opacity-50"
		>
			{m('event.manage.inviteSend')}
		</button>
	</BottomSheet>
{/if}
