<!--
	Compact event card for horizontal scrollers (DESIGN section 9 "Event Card (Horizontal Scroll)").
	Exported for the home feed (composed by WP3).
-->
<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { getLocale, m } from '$lib/i18n';
	import type { Event } from '$lib/types';
	import { displayName, formatEventTime, locationText } from './eventState';

	interface Props {
		event: Event;
	}

	let { event }: Props = $props();

	const locale = getLocale();
	const place = $derived(locationText(event));
	const going = $derived(event.participants.filter((p) => p.status === 'ACCEPTED'));
	const dayLabel = $derived(
		new Date(event.scheduledAt).toLocaleDateString(locale, { weekday: 'long' })
	);
</script>

<a
	href="/events/{event.id}"
	class="flex-shrink-0 w-64 block bg-surface-container-low rounded-xl p-4 shadow-sm hover:scale-[1.02] transition-transform spring-bounce"
>
	<div class="flex justify-between items-start mb-3 gap-2">
		<span
			class="bg-secondary-container text-on-secondary-container px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-tighter"
		>
			{dayLabel} · {formatEventTime(event.scheduledAt, locale)}
		</span>
		<span class="text-[10px] font-label font-bold text-on-surface-variant">
			{m('event.card.players', { count: event.participantCount, max: event.maxParticipants })}
		</span>
	</div>
	<h4 class="font-bold text-base mb-1 line-clamp-1 text-on-surface">{event.title}</h4>
	{#if place}
		<p class="text-xs text-on-surface-variant flex items-center gap-1 mb-3 truncate">
			<span class="material-symbols-outlined text-[14px]" aria-hidden="true">location_on</span>
			<span class="truncate">{place}</span>
		</p>
	{/if}
	<div class="flex -space-x-2">
		{#each going.slice(0, 4) as p (p.id)}
			<Avatar src={p.avatarUrl} name={displayName(p)} size="xs" className="ring-2 ring-surface-container-low" />
		{/each}
		{#if going.length > 4}
			<div
				class="w-6 h-6 rounded-full ring-2 ring-surface-container-low bg-surface-container-high flex items-center justify-center text-[8px] font-bold text-on-surface"
			>
				+{going.length - 4}
			</div>
		{/if}
	</div>
</a>
