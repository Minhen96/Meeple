<script lang="ts">
	import { eventsApi } from '$lib/api/events';
	import { m } from '$lib/i18n';
	import EventCard from '$lib/components/event/EventCard.svelte';
	import MonthCalendar from '$lib/components/event/MonthCalendar.svelte';
	import { eventErrorMessage } from '$lib/components/event/eventState';
	import { eventsViewHref, type EventsTab } from '$lib/components/event/eventsView';
	import type { MessageKey } from '$lib/i18n';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	// Writable deriveds: follow load data, extended locally by "Load more" on the community tab.
	let events = $derived(data.events);
	let nextCursor = $derived(data.nextCursor);
	let loadingMore = $state(false);
	let moreError = $state<string | null>(null);

	const tabs: { value: EventsTab; label: MessageKey }[] = [
		{ value: 'upcoming', label: 'event.tabs.upcoming' },
		{ value: 'past', label: 'event.tabs.past' },
		{ value: 'community', label: 'event.tabs.community' }
	];

	const empty = $derived(
		{
			upcoming: { title: m('event.empty.upcomingTitle'), body: m('event.empty.upcomingBody'), cta: true },
			past: { title: m('event.empty.pastTitle'), body: m('event.empty.pastBody'), cta: false },
			community: { title: m('event.empty.communityTitle'), body: m('event.empty.communityBody'), cta: true }
		}[data.tab]
	);

	async function loadMore() {
		if (!nextCursor) return;
		loadingMore = true;
		moreError = null;
		try {
			const page = await eventsApi.getCommunity({ cursor: nextCursor });
			events = [...events, ...page.items];
			nextCursor = page.hasMore ? page.nextCursor : null;
		} catch (err) {
			moreError = eventErrorMessage(err);
		} finally {
			loadingMore = false;
		}
	}
</script>

<svelte:head><title>{m('event.page.metaTitle')} — Meeple</title></svelte:head>

<section class="mb-5 flex items-end justify-between gap-3">
	<div class="space-y-1">
		<h2 class="text-3xl font-headline font-extrabold tracking-tight">{m('event.page.title')}</h2>
		<p class="text-on-surface-variant text-sm">{m('event.page.subtitle')}</p>
	</div>
	<a
		href="/events/create"
		class="flex-shrink-0 flex items-center gap-1 px-4 py-2 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary text-sm font-label font-bold shadow-md hover:scale-[1.02] transition-transform spring-bounce"
	>
		<span class="material-symbols-outlined text-[18px]" aria-hidden="true">add</span>
		{m('event.action.create')}
	</a>
</section>

<!-- List / Calendar toggle (SCREENS section 6.1) -->
<div class="flex gap-1 bg-surface-container-low p-1 rounded-full mb-4 w-fit" role="group" aria-label={m('event.view.label')}>
	{#each [{ value: 'list', icon: 'view_agenda', label: m('event.view.list') }, { value: 'calendar', icon: 'calendar_month', label: m('event.view.calendar') }] as opt (opt.value)}
		<a
			href={eventsViewHref(data.tab, opt.value === 'calendar' ? 'calendar' : 'list')}
			aria-current={data.view === opt.value ? 'page' : undefined}
			class="flex items-center gap-1 px-4 py-1.5 rounded-full text-sm font-label font-bold transition-colors
				{data.view === opt.value ? 'bg-primary text-on-primary' : 'text-on-surface-variant'}"
		>
			<span class="material-symbols-outlined text-[18px]" aria-hidden="true">{opt.icon}</span>
			{opt.label}
		</a>
	{/each}
</div>

{#if data.view === 'calendar'}
	<MonthCalendar />
{:else}
	<nav class="flex gap-2 mb-5" aria-label={m('event.page.metaTitle')}>
		{#each tabs as t (t.value)}
			<a
				href={eventsViewHref(t.value, 'list')}
				aria-current={data.tab === t.value ? 'page' : undefined}
				class="px-4 py-2 rounded-full text-sm font-label font-bold transition-colors
					{data.tab === t.value ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
			>
				{m(t.label)}
			</a>
		{/each}
	</nav>

	{#if data.loadFailed}
		<div class="text-center py-16 text-on-surface-variant" role="alert">
			<span class="material-symbols-outlined text-5xl mb-3 block opacity-40" aria-hidden="true">cloud_off</span>
			<p class="font-semibold">{m('event.list.loadError')}</p>
			<a href={eventsViewHref(data.tab, 'list')} class="inline-block mt-3 text-sm font-bold text-primary">
				{m('common.retry')}
			</a>
		</div>
	{:else if events.length === 0}
		<div class="text-center py-16 text-on-surface-variant">
			<span class="material-symbols-outlined text-5xl mb-3 block opacity-40" aria-hidden="true">event</span>
			<p class="font-semibold">{empty.title}</p>
			<p class="text-sm mt-1">{empty.body}</p>
			{#if empty.cta}
				<a
					href="/events/create"
					class="inline-block mt-4 px-5 py-2.5 rounded-full bg-primary text-on-primary text-sm font-label font-bold"
				>
					{m('event.action.create')}
				</a>
			{/if}
		</div>
	{:else}
		<div class="space-y-4">
			{#each events as event (event.id)}
				<EventCard {event} muted={data.tab === 'past'} />
			{/each}
		</div>
		{#if data.tab === 'community' && nextCursor}
			<div class="mt-6 text-center">
				<button
					type="button"
					onclick={loadMore}
					disabled={loadingMore}
					class="px-5 py-2.5 rounded-full bg-surface-container-high text-on-surface text-sm font-label font-bold disabled:opacity-50 spring-bounce"
				>
					{loadingMore ? m('common.loading') : m('event.list.loadMore')}
				</button>
				{#if moreError}
					<p class="mt-2 text-sm text-error" role="alert">{moreError}</p>
				{/if}
			</div>
		{/if}
	{/if}
{/if}
