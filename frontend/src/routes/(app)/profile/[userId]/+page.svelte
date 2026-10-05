<script lang="ts">
	// Another user's profile (SCREENS_AND_STATES section 8.2): Add Friend → Pending → Friends
	// button, "···" menu, stats bento, favourites and tabs. Blocked either way → 404 (load).
	import Button from '$lib/components/ui/Button.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ProfileHero from '$lib/components/layout/profile/ProfileHero.svelte';
	import StatsBento from '$lib/components/layout/profile/StatsBento.svelte';
	import ProfileContent from '$lib/components/layout/profile/ProfileContent.svelte';
	import { bentoStats } from '$lib/components/layout/profile/profileStats';
	import { ApiRequestError } from '$lib/api/client';
	import { friendsApi } from '$lib/api/friends';
	import { errorMessage, m, type MessageKey } from '$lib/i18n';
	import { toast } from 'svelte-sonner';
	import type { FriendStatusValue } from '$lib/types';
	import ProfileActionsSlot from './ProfileActionsSlot.svelte';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	let localStatus = $state<FriendStatusValue | null>(null);
	let localRequestId = $state<string | null>(null);
	let loading = $state(false);
	let confirmCancel = $state(false);
	let confirmUnfriend = $state(false);

	const status = $derived(localStatus ?? data.friendStatus.status);
	const requestId = $derived(localRequestId ?? data.friendStatus.requestId);
	const name = $derived(data.user.displayName || data.user.username);
	const stats = $derived(bentoStats(data.stats, data.collection, null));

	$effect(() => {
		// Reset local overrides when the profile changes (reading the id tracks it).
		void data.user.id;
		localStatus = null;
		localRequestId = null;
	});

	const buttonLabel = $derived<MessageKey | null>(
		status === 'NONE'
			? 'account.friend.add'
			: status === 'PENDING_SENT'
				? 'account.friend.pending'
				: status === 'PENDING_RECEIVED'
					? 'account.friend.accept'
					: status === 'FRIENDS'
						? 'account.friend.friends'
						: null
	);

	async function run(action: () => Promise<void>) {
		loading = true;
		try {
			await action();
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR'));
		} finally {
			loading = false;
		}
	}

	function handleFriendAction() {
		if (status === 'PENDING_SENT') {
			confirmCancel = true;
		} else if (status === 'FRIENDS') {
			confirmUnfriend = true;
		} else if (status === 'NONE') {
			void run(async () => {
				const req = await friendsApi.sendRequest(data.user.id);
				localRequestId = req.id;
				localStatus = 'PENDING_SENT';
			});
		} else if (status === 'PENDING_RECEIVED' && requestId) {
			void run(async () => {
				await friendsApi.accept(requestId);
				localStatus = 'FRIENDS';
			});
		}
	}
</script>

<svelte:head><title>{name} — {m('common.appName')}</title></svelte:head>

<ProfileHero user={data.user}>
	{#snippet actions()}
		<div class="flex gap-2 w-full max-w-xs">
			{#if status !== 'BLOCKED' && buttonLabel}
				<Button
					className="flex-1"
					variant={status === 'FRIENDS' || status === 'PENDING_SENT' ? 'secondary' : 'primary'}
					disabled={loading}
					onclick={handleFriendAction}
				>
					{#if status === 'FRIENDS'}
						<span class="material-symbols-outlined text-[18px]" aria-hidden="true">check</span>
					{/if}
					{m(buttonLabel)}
				</Button>
			{/if}
			<ProfileActionsSlot userId={data.user.id} {name} />
		</div>
	{/snippet}
</ProfileHero>

<StatsBento {stats} />

<ProfileContent
	posts={data.posts}
	taggedPosts={data.taggedPosts}
	collection={data.collection}
	own={false}
	collectionVisible={data.isFriend || localStatus === 'FRIENDS'}
/>

{#if confirmCancel}
	<ConfirmDialog
		title={m('account.friend.cancelTitle')}
		message={m('account.friend.cancelBody', { name })}
		confirmLabel={m('account.friend.cancelAction')}
		onConfirm={() => {
			confirmCancel = false;
			if (!requestId) return;
			const id = requestId;
			void run(async () => {
				await friendsApi.cancel(id);
				localStatus = 'NONE';
				localRequestId = null;
			});
		}}
		onCancel={() => (confirmCancel = false)}
	/>
{/if}

{#if confirmUnfriend}
	<ConfirmDialog
		danger
		icon="person_remove"
		title={m('account.friend.unfriendTitle', { name })}
		message={m('account.friend.unfriendBody')}
		confirmLabel={m('account.friend.unfriendAction')}
		onConfirm={() => {
			confirmUnfriend = false;
			void run(async () => {
				await friendsApi.unfriend(data.user.id);
				localStatus = 'NONE';
				localRequestId = null;
			});
		}}
		onCancel={() => (confirmUnfriend = false)}
	/>
{/if}
