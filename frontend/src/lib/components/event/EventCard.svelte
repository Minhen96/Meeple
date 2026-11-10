<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { getLocale, m } from '$lib/i18n';
	import type { Event } from '$lib/types';
	import {
		displayName,
		formatEventTime,
		locationText,
		statusChipClass,
		statusLabel
	} from './eventState';

	interface Props {
		event: Event;
		/** Past events render muted (SCREENS section 6.2). */
		muted?: boolean;
		/**
		 * Grid tile from md up (cover on top, details stacked) for multi-column lists. Below md the
		 * card keeps the phone row layout either way.
		 */
		tile?: boolean;
	}

	let { event, muted = false, tile = false }: Props = $props();

	const locale = getLocale();
	const date = $derived(new Date(event.scheduledAt));
	const place = $derived(locationText(event));
	const others = $derived(event.participants.filter((p) => p.status === 'ACCEPTED' && p.id !== event.host.id));
</script>

<a
	href="/events/{event.id}"
	class="group block bg-surface-container-lowest rounded-xl shadow-sm hover:shadow-md transition-all overflow-hidden spring-bounce
		focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary
		{tile ? 'md:flex md:flex-col md:hover:-translate-y-0.5' : ''}
		{muted ? 'opacity-70' : ''}"
>
	<div class="flex gap-4 p-4 {tile ? 'md:flex-col md:gap-0 md:p-0' : ''}">
		{#if event.game?.thumbnailUrl}
			<div class="w-20 h-20 rounded-lg overflow-hidden flex-shrink-0 {tile ? 'md:w-full md:h-32 md:rounded-none' : ''}">
				<img
					src={event.game.thumbnailUrl}
					alt={event.game.title}
					class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
				/>
			</div>
		{:else}
			<div
				class="w-20 h-20 flex-shrink-0 bg-primary/10 rounded-lg flex flex-col items-center justify-center
					{tile ? 'md:w-full md:h-32 md:rounded-none md:bg-gradient-to-br md:from-primary-fixed md:to-secondary-fixed' : ''}"
			>
				<p class="text-[10px] font-label font-bold uppercase text-primary">
					{date.toLocaleDateString(locale, { month: 'short' })}
				</p>
				<p class="text-2xl font-extrabold font-headline text-primary leading-none">{date.getDate()}</p>
			</div>
		{/if}

		<div class="flex-1 min-w-0 {tile ? 'md:px-4 md:pt-4' : ''}">
			<div class="flex items-start justify-between gap-2 mb-1">
				<p class="font-bold text-on-surface line-clamp-1 flex-1 {tile ? 'md:font-headline md:text-lg md:leading-snug md:line-clamp-2' : ''}">
					{event.title}
				</p>
				<span class="flex-shrink-0 text-[10px] font-label font-bold px-2 py-0.5 rounded-full {statusChipClass(event.status)}">
					{statusLabel(event.status)}
				</span>
			</div>

			<div class="grid grid-cols-2 gap-x-4 gap-y-1 mt-2 {tile ? 'md:grid-cols-1 md:gap-y-1.5' : ''}">
				<div class="flex items-center gap-1 text-[11px] text-on-surface-variant {tile ? 'md:text-xs md:gap-1.5' : ''}">
					<span class="material-symbols-outlined text-[13px]" aria-hidden="true">person</span>
					<span class="truncate">{displayName(event.host)}</span>
				</div>
				<div class="flex items-center gap-1 text-[11px] text-on-surface-variant {tile ? 'md:text-xs md:gap-1.5' : ''}">
					<span class="material-symbols-outlined text-[13px]" aria-hidden="true">group</span>
					<span>{m('event.card.players', { count: event.participantCount, max: event.maxParticipants })}</span>
				</div>
				<div class="flex items-center gap-1 text-[11px] text-on-surface-variant {tile ? 'md:text-xs md:gap-1.5' : ''}">
					<span class="material-symbols-outlined text-[13px]" aria-hidden="true">schedule</span>
					<span>
						{date.toLocaleDateString(locale, { weekday: 'short', month: 'short', day: 'numeric' })}
						· {formatEventTime(event.scheduledAt, locale)}
					</span>
				</div>
				{#if place}
					<div class="flex items-center gap-1 text-[11px] text-on-surface-variant {tile ? 'md:text-xs md:gap-1.5' : ''}">
						<span class="material-symbols-outlined text-[13px]" aria-hidden="true">location_on</span>
						<span class="truncate">{place}</span>
					</div>
				{/if}
			</div>
		</div>
	</div>

	{#if others.length > 0 || event.myRsvp === 'ACCEPTED' || event.myRsvp === 'INVITED'}
		<div class="flex items-center justify-between px-4 pb-4 gap-3 {tile ? 'md:mt-auto md:pt-4' : ''}">
			<div class="flex -space-x-2">
				{#each others.slice(0, 4) as p (p.id)}
					<Avatar src={p.avatarUrl} name={displayName(p)} size="xs" className="ring-2 ring-surface-container-lowest" />
				{/each}
				{#if others.length > 4}
					<div
						class="w-6 h-6 rounded-full ring-2 ring-surface-container-lowest bg-surface-container-high flex items-center justify-center text-[8px] font-bold text-on-surface"
					>
						+{others.length - 4}
					</div>
				{/if}
			</div>
			{#if !event.isHost && event.myRsvp === 'ACCEPTED'}
				<p class="text-xs font-label font-bold text-tertiary flex items-center gap-1">
					<span class="icon-filled material-symbols-outlined text-[14px]" aria-hidden="true">check_circle</span>
					{m('event.card.going')}
				</p>
			{:else if event.myRsvp === 'INVITED'}
				<p class="text-xs font-label font-bold text-primary flex items-center gap-1">
					<span class="material-symbols-outlined text-[14px]" aria-hidden="true">mail</span>
					{m('event.card.invited')}
				</p>
			{/if}
		</div>
	{/if}
</a>
