<!--
	Monthly calendar (SCREENS section 6.3): 7-column grid, a dot under days with events, prev/next
	month, today highlighted; tapping a day with events opens a bottom sheet listing them.
	Loads its own month range from GET /events/calendar.
-->
<script lang="ts">
	import { eventsApi } from '$lib/api/events';
	import { getLocale, m } from '$lib/i18n';
	import type { Event } from '$lib/types';
	import BottomSheet from './BottomSheet.svelte';
	import EventCard from './EventCard.svelte';
	import { addMonths, gridRange, groupByDay, monthGrid, monthOf, weekdayLabels, type MonthRef } from './calendar';
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

<section class="bg-surface-container-low rounded-lg p-4" aria-busy={loading}>
	<div class="flex items-center justify-between mb-4">
		<button
			type="button"
			onclick={() => (month = addMonths(month, -1))}
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
					onclick={() => (month = monthOf(today))}
					class="px-2 py-0.5 rounded-full text-[11px] font-label font-bold bg-primary/10 text-primary"
				>
					{m('event.calendar.today')}
				</button>
			{/if}
		</div>
		<button
			type="button"
			onclick={() => (month = addMonths(month, 1))}
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
			<button
				type="button"
				disabled={count === 0}
				onclick={() => (selectedKey = cell.key)}
				aria-label={dayAriaLabel(cell.date, count)}
				class="aspect-square rounded-full flex flex-col items-center justify-center gap-0.5 text-sm font-headline transition-colors
					{cell.isToday ? 'bg-primary text-on-primary font-extrabold' : cell.inMonth ? 'text-on-surface' : 'text-on-surface-variant/40'}
					{count > 0 && !cell.isToday ? 'hover:bg-primary/10 font-bold' : ''}
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

{#if selectedCell}
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
