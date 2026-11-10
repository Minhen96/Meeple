<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import PageContainer from '$lib/components/layout/PageContainer.svelte';
	import TwoColumn from '$lib/components/layout/TwoColumn.svelte';
	import { MD_QUERY, watchMedia } from '$lib/utils/media';
	import { m, type MessageKey } from '$lib/i18n';
	import { notificationsApi } from '$lib/api/notifications';
	import {
		notifications,
		notificationCount,
		appendNotifications,
		groupNotifications,
		markAllRead,
		markRead,
		notificationHref,
		removeNotification,
		setUnreadCount
	} from '$lib/stores/notifications';
	import type { Notification } from '$lib/types';
	import {
		NOTIFICATION_FILTERS,
		actorName,
		filterCounts,
		filterNotifications,
		relativeTime,
		typeIcon,
		type NotificationFilter
	} from './format';

	const PAGE_SIZE = 30;

	let loading = $state(true);
	let loadFailed = $state(false);
	let loadingMore = $state(false);
	let nextCursor = $state<string | null>(null);
	let hasMore = $state(false);
	let sentinel = $state<HTMLDivElement | null>(null);

	// Wider screens (SCREENS_AND_STATES section 16): filter chips from md, and from xl a right rail
	// with the unread summary, "Mark all read" and the filters. Phones keep the plain list.
	const XL_QUERY = '(min-width: 1280px)';
	let wide = $state(false);
	let rail = $state(false);
	let filter = $state<NotificationFilter>('all');

	const visible = $derived(filterNotifications($notifications, wide ? filter : 'all'));
	const groups = $derived(groupNotifications(visible));
	const counts = $derived(filterCounts($notifications));

	const FILTER_LABELS: Record<NotificationFilter, MessageKey> = {
		all: 'notif.filter.all',
		unread: 'notif.filter.unread',
		events: 'notif.filter.events',
		social: 'notif.filter.social',
		friends: 'notif.filter.friends',
		library: 'notif.filter.library'
	};
	const FILTER_ICONS: Record<NotificationFilter, string> = {
		all: 'notifications',
		unread: 'mark_email_unread',
		events: 'event',
		social: 'chat_bubble',
		friends: 'group',
		library: 'menu_book'
	};

	onMount(() => {
		const stopMd = watchMedia(MD_QUERY, (matches) => {
			wide = matches;
			if (!matches) filter = 'all';
		});
		const stopXl = watchMedia(XL_QUERY, (matches) => (rail = matches));
		return () => {
			stopMd();
			stopXl();
		};
	});

	async function loadFirstPage() {
		loading = true;
		loadFailed = false;
		try {
			const [page, count] = await Promise.all([
				notificationsApi.list(null, PAGE_SIZE),
				notificationsApi.getUnreadCount()
			]);
			notifications.set(page.items);
			setUnreadCount(count);
			nextCursor = page.nextCursor;
			hasMore = page.hasMore;
		} catch {
			loadFailed = true;
		} finally {
			loading = false;
		}
	}

	async function loadMore() {
		if (loadingMore || !hasMore || !nextCursor) return;
		loadingMore = true;
		try {
			const page = await notificationsApi.list(nextCursor, PAGE_SIZE);
			appendNotifications(page.items);
			nextCursor = page.nextCursor;
			hasMore = page.hasMore;
		} catch {
			toast.error(m('notif.list.loadFailed'));
		} finally {
			loadingMore = false;
		}
	}

	onMount(() => {
		void loadFirstPage();
	});

	// Infinite scroll: load the next page when the sentinel below the list comes into view
	$effect(() => {
		const el = sentinel;
		if (!el || typeof IntersectionObserver === 'undefined') return;
		const observer = new IntersectionObserver(
			(entries) => {
				if (entries.some((e) => e.isIntersecting)) void loadMore();
			},
			{ rootMargin: '200px' }
		);
		observer.observe(el);
		return () => observer.disconnect();
	});

	async function handleMarkAllRead() {
		try {
			await notificationsApi.markAllRead();
			markAllRead();
		} catch {
			toast.error(m('notif.action.failed'));
		}
	}

	async function markOneRead(n: Notification) {
		if (n.read) return;
		await notificationsApi.markRead(n.id);
		markRead(n.id);
	}

	async function open(n: Notification) {
		const href = notificationHref(n);
		// Navigation must not wait on (or fail with) the read receipt
		markOneRead(n).catch(() => undefined);
		await goto(href);
	}

	async function handleMarkRead(n: Notification) {
		try {
			await markOneRead(n);
		} catch {
			toast.error(m('notif.action.failed'));
		}
	}

	async function handleDelete(n: Notification) {
		try {
			await notificationsApi.remove(n.id);
			removeNotification(n.id);
		} catch {
			toast.error(m('notif.action.failed'));
		}
	}

	const GROUP_LABELS = {
		today: 'notif.group.today',
		thisWeek: 'notif.group.thisWeek',
		earlier: 'notif.group.earlier'
	} as const;
</script>

<svelte:head><title>{m('notif.page.title')} — Meeple</title></svelte:head>

{#snippet filterChips(vertical: boolean)}
	<div
		role="group"
		aria-label={m('notif.filter.label')}
		class={vertical ? 'flex flex-col gap-1' : 'flex flex-wrap gap-2'}
	>
		{#each NOTIFICATION_FILTERS as f (f)}
			{@const active = filter === f}
			{#if f === 'all' || f === 'unread' || counts[f] > 0}
				<button
					type="button"
					onclick={() => (filter = f)}
					aria-pressed={active}
					class="flex items-center gap-2 font-label font-bold text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary spring-bounce
						{vertical ? 'w-full px-3 py-2.5 rounded-full text-left' : 'px-4 py-2 rounded-full'}
						{active
						? 'bg-primary text-on-primary'
						: vertical
							? 'text-on-surface-variant hover:bg-surface-container-high hover:text-on-surface'
							: 'bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest hover:text-on-surface'}"
				>
					{#if vertical}
						<span class="material-symbols-outlined text-[20px]" aria-hidden="true">{FILTER_ICONS[f]}</span>
					{/if}
					<span class={vertical ? 'flex-1' : ''}>{m(FILTER_LABELS[f])}</span>
					<span
						class="min-w-[1.5rem] px-1.5 py-0.5 rounded-full text-[11px] text-center
							{active ? 'bg-on-primary/20 text-on-primary' : 'bg-surface-container-highest text-on-surface-variant'}"
					>
						{counts[f]}
					</span>
				</button>
			{/if}
		{/each}
	</div>
{/snippet}

{#snippet railContent()}
	<div class="bg-surface-container-low rounded-lg p-5 space-y-6">
		<div class="flex items-center gap-3">
			<span
				class="w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0
					{$notificationCount > 0 ? 'bg-primary/10 text-primary' : 'bg-tertiary/10 text-tertiary'}"
			>
				<span class="icon-filled material-symbols-outlined" aria-hidden="true">
					{$notificationCount > 0 ? 'notifications_active' : 'check_circle'}
				</span>
			</span>
			<p class="font-headline font-extrabold text-lg text-on-surface">
				{$notificationCount > 0
					? m('notif.rail.unread', { count: $notificationCount })
					: m('notif.rail.caughtUp')}
			</p>
		</div>
		{#if $notificationCount > 0}
			<button
				onclick={handleMarkAllRead}
				class="w-full flex items-center justify-center gap-2 py-3 rounded-full bg-gradient-to-r from-primary to-primary-container text-on-primary font-label font-bold text-sm shadow-[0_8px_24px_rgba(137,81,0,0.20)] hover:scale-[1.02] transition-transform spring-bounce"
			>
				<span class="material-symbols-outlined text-[18px]" aria-hidden="true">done_all</span>
				{m('notif.page.markAllRead')}
			</button>
		{/if}
		{#if !loading && !loadFailed && $notifications.length > 0}
			<div class="space-y-2">
				<p class="px-3 text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant">
					{m('notif.filter.title')}
				</p>
				{@render filterChips(true)}
			</div>
		{/if}
	</div>
{/snippet}

<PageContainer width="wide">
<TwoColumn aside={rail ? railContent : undefined} asideLabel={m('notif.filter.label')}>
<div class="lg:max-w-3xl lg:mx-auto xl:max-w-none">
<div class="flex items-center gap-3 mb-6 mt-3">
	<button
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
		aria-label={m('notif.page.back')}
	>
		<span class="material-symbols-outlined text-[22px]">arrow_back</span>
	</button>
	<h2 class="text-2xl md:text-3xl md:tracking-tight font-extrabold font-headline">{m('notif.page.title')}</h2>
	{#if $notificationCount > 0 && !rail}
		<button
			onclick={handleMarkAllRead}
			class="ml-auto text-sm text-primary font-label font-semibold md:px-4 md:py-2 md:rounded-full md:hover:bg-primary/10 md:transition-colors"
		>
			{m('notif.page.markAllRead')}
		</button>
	{/if}
</div>

{#if wide && !rail && !loading && !loadFailed && $notifications.length > 0}
	<div class="mb-6">{@render filterChips(false)}</div>
{/if}

{#if loading}
	<div class="space-y-3" aria-busy="true">
		{#each Array(5) as _, i (i)}
			<div class="flex items-start gap-3 p-4 rounded-xl bg-surface-container-low">
				<div class="skeleton rounded-full w-10 h-10 flex-shrink-0"></div>
				<div class="flex-1 space-y-2">
					<div class="skeleton rounded h-3 w-1/3"></div>
					<div class="skeleton rounded h-3 w-2/3"></div>
				</div>
			</div>
		{/each}
	</div>
{:else if loadFailed}
	<div class="flex flex-col items-center gap-3 py-20 text-center text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl opacity-40">cloud_off</span>
		<p class="font-semibold">{m('notif.list.loadFailed')}</p>
		<button onclick={loadFirstPage} class="text-sm text-primary font-label font-semibold">
			{m('notif.list.retry')}
		</button>
	</div>
{:else if $notifications.length === 0}
	<div class="flex flex-col items-center gap-3 py-20 text-center text-on-surface-variant md:bg-surface-container-low md:rounded-lg">
		<span class="icon-filled material-symbols-outlined text-5xl opacity-40">check_circle</span>
		<p class="font-semibold">{m('notif.empty.title')}</p>
		<p class="text-sm">{m('notif.empty.body')}</p>
	</div>
{:else if visible.length === 0}
	<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant bg-surface-container-low rounded-lg">
		<span class="material-symbols-outlined text-5xl opacity-40" aria-hidden="true">filter_list_off</span>
		<p class="font-semibold">{m('notif.filter.empty')}</p>
		<button
			type="button"
			onclick={() => (filter = 'all')}
			class="text-sm text-primary font-label font-semibold hover:underline"
		>
			{m('notif.filter.showAll')}
		</button>
	</div>
{:else}
	<div class="space-y-6">
		{#each groups as group (group.key)}
			<section>
				<h3
					class="text-xs font-label font-bold uppercase tracking-wider text-on-surface-variant mb-2 px-1"
				>
					{m(GROUP_LABELS[group.key])}
				</h3>
				<ul class="space-y-2">
					{#each group.items as n (n.id)}
						{@const name = actorName(n)}
						<li
							class="group relative flex items-start gap-3 p-4 rounded-xl transition-colors md:items-center md:px-5
								{n.read
								? 'bg-surface md:hover:bg-surface-container-low'
								: 'bg-surface-container-low md:hover:bg-surface-container'}"
						>
							{#if !n.read}
								<span
									class="absolute left-1.5 top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-primary"
								>
									<span class="sr-only">{m('notif.item.unread')}</span>
								</span>
							{/if}

							<button
								class="flex flex-1 min-w-0 items-start gap-3 text-left rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary md:items-center md:gap-4"
								onclick={() => open(n)}
							>
								{#if n.actor && !n.actor.deleted}
									<Avatar src={n.actor.avatarUrl} name={name ?? ''} size="md" />
								{:else}
									<div
										class="w-10 h-10 rounded-full bg-surface-container flex items-center justify-center flex-shrink-0"
									>
										<span class="material-symbols-outlined text-[20px] text-on-surface-variant">
											{typeIcon(n.type)}
										</span>
									</div>
								{/if}
								<div class="flex-1 min-w-0">
									<p class="text-sm font-semibold text-on-surface leading-snug">{n.title}</p>
									{#if n.body}
										<p class="text-sm text-on-surface-variant leading-snug mt-0.5">{n.body}</p>
									{/if}
								</div>
								<time
									class="text-xs text-on-surface-variant flex-shrink-0 mt-0.5"
									datetime={n.createdAt}
								>
									{relativeTime(n.createdAt)}
								</time>
							</button>

							<div class="flex flex-col gap-1 flex-shrink-0 md:flex-row">
								{#if !n.read}
									<button
										onclick={() => handleMarkRead(n)}
										class="w-8 h-8 rounded-full flex items-center justify-center text-tertiary hover:bg-tertiary/10 transition-colors"
										aria-label={m('notif.item.markRead')}
										title={m('notif.item.markRead')}
									>
										<span class="material-symbols-outlined text-[18px]">done</span>
									</button>
								{/if}
								<button
									onclick={() => handleDelete(n)}
									class="w-8 h-8 rounded-full flex items-center justify-center text-error hover:bg-error/10 transition-colors"
									aria-label={m('notif.item.delete')}
									title={m('notif.item.delete')}
								>
									<span class="material-symbols-outlined text-[18px]">delete</span>
								</button>
							</div>
						</li>
					{/each}
				</ul>
			</section>
		{/each}
	</div>

	<div bind:this={sentinel} class="h-8"></div>
	{#if loadingMore}
		<p class="text-center text-xs text-on-surface-variant py-4">{m('notif.list.loadingMore')}</p>
	{/if}
{/if}
</div>
</TwoColumn>
</PageContainer>
