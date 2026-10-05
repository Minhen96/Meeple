<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { m } from '$lib/i18n';
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
	import { actorName, relativeTime, typeIcon } from './format';

	const PAGE_SIZE = 30;

	let loading = $state(true);
	let loadFailed = $state(false);
	let loadingMore = $state(false);
	let nextCursor = $state<string | null>(null);
	let hasMore = $state(false);
	let sentinel = $state<HTMLDivElement | null>(null);

	const groups = $derived(groupNotifications($notifications));

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

<div class="flex items-center gap-3 mb-6 mt-3">
	<button
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
		aria-label={m('notif.page.back')}
	>
		<span class="material-symbols-outlined text-[22px]">arrow_back</span>
	</button>
	<h2 class="text-2xl font-extrabold font-headline">{m('notif.page.title')}</h2>
	{#if $notificationCount > 0}
		<button
			onclick={handleMarkAllRead}
			class="ml-auto text-sm text-primary font-label font-semibold"
		>
			{m('notif.page.markAllRead')}
		</button>
	{/if}
</div>

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
	<div class="flex flex-col items-center gap-3 py-20 text-center text-on-surface-variant">
		<span class="icon-filled material-symbols-outlined text-5xl opacity-40">check_circle</span>
		<p class="font-semibold">{m('notif.empty.title')}</p>
		<p class="text-sm">{m('notif.empty.body')}</p>
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
							class="group relative flex items-start gap-3 p-4 rounded-xl transition-colors
								{n.read ? 'bg-surface' : 'bg-surface-container-low'}"
						>
							{#if !n.read}
								<span
									class="absolute left-1.5 top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-primary"
								>
									<span class="sr-only">{m('notif.item.unread')}</span>
								</span>
							{/if}

							<button
								class="flex flex-1 min-w-0 items-start gap-3 text-left"
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

							<div class="flex flex-col gap-1 flex-shrink-0">
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
