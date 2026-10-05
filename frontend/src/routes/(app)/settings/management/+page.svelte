<script lang="ts">
	// Admin only: promote a friend to admin.
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { fade, fly } from 'svelte/transition';
	import { friendsApi } from '$lib/api/friends';
	import { adminApi } from '$lib/api/admin';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import SkeletonPattern from '$lib/components/ui/SkeletonPattern.svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import { m } from '$lib/i18n';
	import { currentUser } from '$lib/stores/auth';
	import type { User } from '$lib/types';

	let friends = $state<User[]>([]);
	let loading = $state(true);
	let promotingId = $state<string | null>(null);
	let pending = $state<User | null>(null);
	let searchQuery = $state('');

	const filteredFriends = $derived(
		friends.filter((f) => {
			const q = searchQuery.toLowerCase();
			return (
				!f.isAdmin &&
				(f.username.toLowerCase().includes(q) || (f.displayName?.toLowerCase() || '').includes(q))
			);
		})
	);

	onMount(async () => {
		if (!$currentUser?.isAdmin) {
			void goto('/');
			return;
		}
		loading = true;
		try {
			const res = await friendsApi.getFriends(0, 100);
			friends = res.data;
		} catch {
			toast.error(m('account.admin.loadFailed'));
		} finally {
			loading = false;
		}
	});

	const nameOf = (user: User) => user.displayName || user.username;

	async function promote(user: User) {
		pending = null;
		promotingId = user.id;
		try {
			await adminApi.promoteUser(user.id);
			toast.success(m('account.admin.promoted', { name: nameOf(user) }));
			friends = friends.filter((f) => f.id !== user.id);
		} catch {
			toast.error(m('account.admin.promoteFailed'));
		} finally {
			promotingId = null;
		}
	}
</script>

<svelte:head><title>{m('account.admin.title')} — {m('common.appName')}</title></svelte:head>

<div class="space-y-6 pb-24">
	<PageHeader eyebrow={m('account.settings.sectionManagement')} title={m('account.admin.title')} />

	<div class="bg-primary/10 rounded-2xl p-4 flex gap-3 items-start">
		<span class="material-symbols-outlined text-primary text-[20px]">info</span>
		<p class="text-xs text-on-surface-variant leading-relaxed">{m('account.admin.intro')}</p>
	</div>

	<div class="relative">
		<span class="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant/50 text-[18px]">search</span>
		<input
			type="text"
			placeholder={m('account.admin.search')}
			aria-label={m('account.admin.search')}
			bind:value={searchQuery}
			class="w-full h-11 bg-surface-container-high rounded-xl pl-11 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/40 transition-shadow"
		/>
	</div>

	<div class="space-y-2">
		{#if loading}
			<SkeletonPattern variant="user" count={3} />
		{:else if filteredFriends.length === 0}
			<div class="text-center py-20 bg-surface-container-lowest rounded-3xl" in:fade>
				<span class="material-symbols-outlined text-4xl text-on-surface-variant/20 block mb-3">person_search</span>
				<p class="text-sm font-bold text-on-surface-variant">{m('account.admin.empty')}</p>
				<p class="text-[10px] text-on-surface-variant opacity-60 mt-1">{m('account.admin.emptyHint')}</p>
			</div>
		{:else}
			{#each filteredFriends as friend (friend.id)}
				<div class="flex items-center justify-between p-3 bg-surface-container-lowest rounded-2xl" in:fly={{ y: 10 }}>
					<div class="flex items-center gap-3">
						<Avatar src={friend.avatarUrl} name={nameOf(friend)} size="md" />
						<div>
							<p class="text-sm font-bold text-on-surface">{nameOf(friend)}</p>
							<p class="text-[10px] text-on-surface-variant">@{friend.username}</p>
						</div>
					</div>
					<button
						onclick={() => (pending = friend)}
						disabled={promotingId === friend.id}
						class="h-9 px-4 rounded-lg bg-primary text-on-primary text-xs font-bold shadow-sm active:scale-95 disabled:opacity-50 transition-all flex items-center gap-2"
					>
						<span class="material-symbols-outlined text-[16px] {promotingId === friend.id ? 'animate-spin' : ''}">
							{promotingId === friend.id ? 'progress_activity' : 'add_moderator'}
						</span>
						{m('account.admin.promote')}
					</button>
				</div>
			{/each}
		{/if}
	</div>
</div>

{#if pending}
	{@const target = pending}
	<ConfirmDialog
		icon="add_moderator"
		title={m('account.admin.confirmTitle')}
		message={m('account.admin.confirmBody', { name: nameOf(target) })}
		confirmLabel={m('account.admin.promote')}
		onConfirm={() => promote(target)}
		onCancel={() => (pending = null)}
	/>
{/if}
