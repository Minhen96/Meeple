<script lang="ts">
	import type { PageData } from './$types';
	import type { User } from '$lib/types';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import { toast } from 'svelte-sonner';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const PAGE_SIZE = 20;

	// Writable deriveds: reset when data reloads, overridden locally on unfriend / load more.
	let friends = $derived<User[]>(data.friends);
	let hasMore = $derived(data.meta.hasMore);
	let total = $derived(data.meta.total);
	let nextPage = $state(1);
	let loadingMore = $state(false);
	let confirming = $state<User | null>(null);

	async function loadMore() {
		if (loadingMore) return;
		loadingMore = true;
		try {
			const res = await friendsApi.getFriends(nextPage, PAGE_SIZE);
			const known = new Set(friends.map((f) => f.id));
			friends = [...friends, ...res.data.filter((f) => !known.has(f.id))];
			hasMore = res.meta.hasMore;
			nextPage += 1;
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : null));
		} finally {
			loadingMore = false;
		}
	}

	async function unfriend(user: User) {
		confirming = null;
		try {
			await friendsApi.unfriend(user.id);
			friends = friends.filter((f) => f.id !== user.id);
			total = Math.max(0, total - 1);
			toast.success(m('social.friends.removed'));
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : null));
		}
	}
</script>

<svelte:head><title>{m('social.friends.title')} — Meeple</title></svelte:head>

<div class="pb-32 pt-6">
	<div class="mb-8 flex items-center gap-4">
		<button
			type="button"
			onclick={() => history.back()}
			aria-label={m('social.detail.back')}
			class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-all hover:text-primary active:scale-95"
		>
			<span class="material-symbols-outlined text-[20px]">arrow_back</span>
		</button>
		<div>
			<h2 class="font-headline text-xl font-black tracking-tight text-on-surface">
				{m('social.friends.title')}
			</h2>
			{#if total > 0}
				<p class="font-label text-xs text-on-surface-variant">
					{m('social.friends.count', { count: total })}
				</p>
			{/if}
		</div>
	</div>

	{#if friends.length > 0}
		<ul class="space-y-3">
			{#each friends as user (user.id)}
				<li
					class="flex items-center gap-4 rounded-3xl bg-surface-container-low p-4 shadow-sm transition-colors hover:bg-surface-container"
				>
					<a href="/profile/{user.id}"
						><Avatar src={user.avatarUrl} name={user.displayName ?? user.username} size="lg" /></a
					>
					<a href="/profile/{user.id}" class="min-w-0 flex-1">
						<p class="truncate text-sm font-extrabold text-on-surface">
							{user.displayName ?? user.username}
						</p>
						<p class="truncate text-xs text-on-surface-variant">@{user.username}</p>
					</a>
					<button
						type="button"
						onclick={() => (confirming = user)}
						class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-highest text-on-surface-variant transition-all hover:text-error active:scale-95"
						aria-label={m('social.friends.unfriend')}
					>
						<span class="material-symbols-outlined text-[20px]">person_remove</span>
					</button>
				</li>
			{/each}
		</ul>
		{#if hasMore}
			<div class="pt-4 text-center">
				<button
					type="button"
					onclick={loadMore}
					disabled={loadingMore}
					class="text-sm font-bold text-primary disabled:opacity-50"
				>
					{loadingMore ? m('common.loading') : m('common.loadMore')}
				</button>
			</div>
		{/if}
	{:else}
		<div class="py-20 text-center">
			<span class="material-symbols-outlined mb-4 text-5xl text-on-surface-variant/40"
				>group_off</span
			>
			<p class="text-lg font-bold text-on-surface-variant">{m('social.friends.empty')}</p>
			<a href="/people" class="mt-2 inline-block text-sm font-bold text-primary hover:underline"
				>{m('social.friends.findPeople')}</a
			>
		</div>
	{/if}
</div>

{#if confirming}
	<ConfirmDialog
		title={m('social.friends.unfriendTitle', {
			name: confirming.displayName ?? confirming.username
		})}
		message={m('social.friends.unfriendBody')}
		confirmLabel={m('social.friends.unfriend')}
		cancelLabel={m('common.cancel')}
		danger
		onConfirm={() => confirming && unfriend(confirming)}
		onCancel={() => (confirming = null)}
	/>
{/if}
