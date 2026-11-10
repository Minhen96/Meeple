<!--
	Monthly calendar (SCREENS section 6.3): 7-column grid, a dot under days with events, prev/next
	month, today highlighted; tapping a day with events opens a bottom sheet listing them.
	From lg up (SCREENS_AND_STATES section 16) it is a split view instead: the agenda of the month
	sits beside the grid and selecting a day narrows it to that day.
	Loads its own month range from GET /events/calendar.
-->
<script lang="ts">
	import { eventsApi } from '$lib/api/events';
	import { getLocale, m } from '$lib/i18n';
	import { onMount } from 'svelte';
	import type { Event } from '$lib/types';
	import { LG_QUERY, watchMedia } from '$lib/utils/media';
	import BottomSheet from './BottomSheet.svelte';
	import EventCard from './EventCard.svelte';
	import { addMonths, agendaDays, gridRange, groupByDay, monthGrid, monthOf, weekdayLabels, type MonthRef } from './calendar';
	import { eventErrorMessage } from './eventState';

	const locale = getLocale();
	const today = new Date();

	let month = $state<MonthRef>(monthOf(today));
	let events = $state<Event[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let selectedKey = $state<string | null>(null);

	const cells = $derived(monthGrid(month, today));
	const byDay = $derived(groupByDay(events));
	const labels = weekdayLabels(locale);
	const monthTitle = $derived(
		new Date(month.year, month.month, 1).toLocaleDateString(locale, { month: 'long', year: 'numeric' })
	);
	const selectedCell = $derived(cells.find((c) => c.key === selectedKey) ?? null);
	const selectedEvents = $derived(selectedKey ? (byDay.get(selectedKey) ?? []) : []);
	const agenda = $derived(agendaDays(cells, byDay, selectedKey));

	// lg+: agenda beside the grid instead of the sheet. Decided after mount so SSR and the first
	// client render agree; a breakpoint change drops the selection so no sheet pops up.
	let split = $state(false);
	onMount(() =>
		watchMedia(LG_QUERY, (matches) => {
			if (matches !== split) selectedKey = null;
			split = matches;
		})
	);

	function selectDay(key: string) {
		selectedKey = split && selectedKey === key ? null : key;
	}

	function changeMonth(next: MonthRef) {
		month = next;
		if (split) selectedKey = null;
	}

	let requestId = 0;

	$effect(() => {
		const { from, to } = gridRange(cells);
		const id = ++requestId;
		loading = true;
		error = null;
		eventsApi
			.getCalendar(from, to)
			.then((result) => {
				if (id === requestId) events = result;
			})
			.catch((err: unknown) => {
				if (id === requestId) error = eventErrorMessage(err);
			})
			.finally(() => {
				if (id === requestId) loading = false;
			});
	});

	function dayAriaLabel(date: Date, count: number): string {
		const label = date.toLocaleDateString(locale, { weekday: 'long', month: 'long', day: 'numeric' });
		return count > 0 ? m('event.calendar.hasEvents', { date: label, count }) : label;
	}
</script>

<div class="lg:grid lg:grid-cols-[minmax(0,1fr)_minmax(0,22rem)] xl:grid-cols-[minmax(0,1fr)_minmax(0,24rem)] lg:gap-6 lg:items-start">
<section class="bg-surface-container-low rounded-lg p-4 md:p-6 lg:sticky lg:top-8" aria-busy={loading}>
	<div class="flex items-center justify-between mb-4">
		<button
			type="button"
			onclick={() => changeMonth(addMonths(month, -1))}
			class="w-10 h-10 rounded-full bg-surface-container-high flex items-center justify-center spring-bounce"
			aria-label={m('event.calendar.prev')}
		>
			<span class="material-symbols-outlined" aria-hidden="true">chevron_left</span>
		</button>
		<div class="flex items-center gap-2">
			<h3 class="font-headline font-extrabold text-lg text-on-surface">{monthTitle}</h3>
			{#if month.year !== today.getFullYear() || month.month !== today.getMonth()}
				<button
					type="button"
					onclick={() => changeMonth(monthOf(today))}
					class="px-2 py-0.5 rounded-full text-[11px] font-label font-bold bg-primary/10 text-primary"
				>
					{m('event.calendar.today')}
				</button>
			{/if}
		</div>
		<button
			type="button"
			onclick={() => changeMonth(addMonths(month, 1))}
			class="w-10 h-10 rounded-full bg-surface-container-high flex items-center justify-center spring-bounce"
			aria-label={m('event.calendar.next')}
		>
			<span class="material-symbols-outlined" aria-hidden="true">chevron_right</span>
		</button>
	</div>

	<div class="grid grid-cols-7 gap-1 text-center mb-1" aria-hidden="true">
		{#each labels as label (label)}
			<span class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant">{label}</span>
		{/each}
	</div>

	<div class="grid grid-cols-7 gap-1 {loading ? 'animate-pulse' : ''}">
		{#each cells as cell (cell.key)}
			{@const count = byDay.get(cell.key)?.length ?? 0}
			{@const selected = split && selectedKey === cell.key}
			<button
				type="button"
				disabled={count === 0}
				onclick={() => selectDay(cell.key)}
				aria-label={dayAriaLabel(cell.date, count)}
				aria-pressed={split ? selected : undefined}
				class="aspect-square md:aspect-auto md:h-14 lg:h-16 rounded-full md:rounded flex flex-col items-center justify-center gap-0.5 text-sm font-headline transition-colors
					{cell.isToday ? 'bg-primary text-on-primary font-extrabold' : cell.inMonth ? 'text-on-surface' : 'text-on-surface-variant/40'}
					{count > 0 && !cell.isToday ? 'hover:bg-primary/10 font-bold' : ''}
					{selected ? 'ring-2 ring-primary bg-primary/10' : ''}
					focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary
					disabled:cursor-default"
			>
				<span>{cell.day}</span>
				<span
					class="w-1.5 h-1.5 rounded-full {count > 0 ? (cell.isToday ? 'bg-on-primary' : 'bg-primary') : 'bg-transparent'}"
					aria-hidden="true"
				></span>
			</button>
		{/each}
	</div>

	{#if error}
		<p class="mt-3 text-sm text-error" role="alert">{error}</p>
	{/if}
</section>

{#if split}
	<section class="mt-6 lg:mt-0 space-y-4" aria-labelledby="calendar-agenda-heading">
		<div class="flex items-center justify-between gap-3 min-h-10">
			<h3 id="calendar-agenda-heading" class="font-headline font-extrabold text-lg text-on-surface">
				{selectedCell
					? m('event.calendar.eventsOn', {
							date: selectedCell.date.toLocaleDateString(locale, { weekday: 'long', month: 'long', day: 'numeric' })
						})
					: m('event.calendar.agendaTitle', { month: monthTitle })}
			</h3>
			{#if selectedCell}
				<button
					type="button"
					onclick={() => (selectedKey = null)}
					class="flex-shrink-0 px-3 py-1.5 rounded-full text-xs font-label font-bold bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest transition-colors spring-bounce"
				>
					{m('event.calendar.showMonth')}
				</button>
			{/if}
		</div>
		{#if loading && agenda.length === 0}
			<div class="space-y-3" aria-hidden="true">
				{#each Array(2) as _, i (i)}
					<div class="h-28 rounded-xl bg-surface-container-low animate-pulse"></div>
				{/each}
			</div>
		{:else if agenda.length === 0}
			<div class="rounded-lg bg-surface-container-low px-6 py-10 text-center text-on-surface-variant">
				<span class="material-symbols-outlined text-4xl mb-2 block opacity-40" aria-hidden="true">event_available</span>
				<p class="text-sm font-semibold">
					{selectedCell ? m('event.calendar.noEvents') : m('event.calendar.noEventsMonth')}
				</p>
				<a href="/events/create" class="inline-block mt-3 text-sm font-label font-bold text-primary hover:underline">
					{m('event.action.create')}
				</a>
			</div>
		{:else}
			{#each agenda as day (day.key)}
				<div class="space-y-2">
					{#if !selectedCell}
						<p class="px-1 text-[11px] font-label font-bold uppercase tracking-widest text-on-surface-variant">
							{day.date.toLocaleDateString(locale, { weekday: 'short', month: 'short', day: 'numeric' })}
						</p>
					{/if}
					{#each day.events as event (event.id)}
						<EventCard {event} muted={event.status === 'COMPLETED'} />
					{/each}
				</div>
			{/each}
		{/if}
	</section>
{/if}
</div>

{#if selectedCell && !split}
	<BottomSheet
		title={m('event.calendar.eventsOn', {
			date: selectedCell.date.toLocaleDateString(locale, { weekday: 'long', month: 'long', day: 'numeric' })
		})}
		onClose={() => (selectedKey = null)}
	>
		{#if selectedEvents.length === 0}
			<p class="text-sm text-on-surface-variant py-6 text-center">{m('event.calendar.noEvents')}</p>
		{:else}
			<div class="space-y-3">
				{#each selectedEvents as event (event.id)}
					<EventCard {event} muted={event.status === 'COMPLETED'} />
				{/each}
			</div>
		{/if}
	</BottomSheet>
{/if}
