<script lang="ts">
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import type { FriendshipStatus } from '$lib/types';
	import { toast } from 'svelte-sonner';

	/**
	 * "Add Friend" → "Pending" → "Friends" (CLAUDE.md social wording). A pending request I sent
	 * can be withdrawn by tapping "Pending"; a request I received is accepted with "Accept" (sending
	 * a request back accepts theirs).
	 */
	interface Props {
		userId: string;
		status: FriendshipStatus;
		onChange?: (status: FriendshipStatus) => void;
		size?: 'sm' | 'md';
	}

	let { userId, status = $bindable(), onChange, size = 'sm' }: Props = $props();
	let busy = $state(false);

	const sizing = $derived(size === 'sm' ? 'px-4 py-1.5 text-xs' : 'px-6 py-2.5 text-sm');

	async function run(next: FriendshipStatus, action: () => Promise<unknown>, success: string) {
		if (busy) return;
		busy = true;
		try {
			const result = await action();
			// Sending to someone who already asked me accepts their request
			const accepted =
				typeof result === 'object' &&
				result !== null &&
				'status' in result &&
				result.status === 'ACCEPTED';
			status = accepted ? 'friends' : next;
			onChange?.(status);
			toast.success(accepted ? m('social.friend.accepted') : success);
		} catch (err) {
			toast.error(
				err instanceof ApiRequestError ? errorMessage(err.code) : m('social.friend.failed')
			);
		} finally {
			busy = false;
		}
	}
</script>

{#if status === 'friends'}
	<span
		class="inline-flex items-center gap-1 rounded-full bg-tertiary-container/40 font-label font-bold text-on-tertiary-container {sizing}"
	>
		<span class="material-symbols-outlined text-[16px]">check</span>{m('social.friend.friends')}
	</span>
{:else if status === 'pending_sent'}
	<button
		type="button"
		disabled={busy}
		onclick={() => run('none', () => friendsApi.cancelTo(userId), m('social.friend.cancelled'))}
		title={m('social.friend.cancel')}
		class="rounded-full bg-surface-container-high font-label font-bold text-on-surface-variant transition-all hover:bg-surface-container-highest active:scale-95 disabled:opacity-50 {sizing}"
	>
		{m('social.friend.pending')}
	</button>
{:else if status === 'pending_received'}
	<button
		type="button"
		disabled={busy}
		onclick={() =>
			run('friends', () => friendsApi.sendRequest(userId), m('social.friend.accepted'))}
		class="rounded-full bg-gradient-to-r from-primary to-primary-container font-label font-bold text-on-primary transition-all hover:scale-105 active:scale-95 disabled:opacity-50 {sizing}"
	>
		{m('social.friend.accept')}
	</button>
{:else}
	<button
		type="button"
		disabled={busy}
		onclick={() =>
			run('pending_sent', () => friendsApi.sendRequest(userId), m('social.friend.requestSent'))}
		class="inline-flex items-center gap-1 rounded-full bg-primary/10 font-label font-bold text-primary transition-all hover:bg-primary/20 active:scale-95 disabled:opacity-50 {sizing}"
	>
		<span class="material-symbols-outlined text-[16px]">person_add</span>{m('social.friend.add')}
	</button>
{/if}
