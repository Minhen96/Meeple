<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import { friendsApi } from '$lib/api/friends';
	import type { FriendStatusValue } from '$lib/types';

	let { data } = $props();

	let localStatus = $state<FriendStatusValue | null>(null);
	let localRequestId = $state<string | null>(null);
	let loading = $state(false);

	let status = $derived(localStatus ?? data.friendStatus.status);
	let requestId = $derived(localRequestId ?? data.friendStatus.requestId);

	$effect(() => {
		// Reset local overrides when the user changes
		data.user.id; 
		localStatus = null;
		localRequestId = null;
	});

	async function handleFriendAction() {
		loading = true;
		try {
			if (status === 'NONE') {
				const req = await friendsApi.sendRequest(data.user.id);
				localRequestId = req.id;
				localStatus = 'PENDING_SENT';
			} else if (status === 'PENDING_SENT' && requestId) {
				// Cancel — not implemented in API yet, show nothing
			} else if (status === 'PENDING_RECEIVED' && requestId) {
				await friendsApi.accept(requestId);
				localStatus = 'FRIENDS';
			} else if (status === 'FRIENDS') {
				await friendsApi.unfriend(data.user.id);
				localStatus = 'NONE';
				localRequestId = null;
			}
		} finally {
			loading = false;
		}
	}

	const buttonLabel = $derived(
		status === 'NONE' ? 'Add Friend'
		: status === 'PENDING_SENT' ? 'Pending'
		: status === 'PENDING_RECEIVED' ? 'Accept Request'
		: status === 'FRIENDS' ? 'Friends'
		: null
	);
</script>

<svelte:head><title>{data.user.displayName ?? data.user.username} — Meeple</title></svelte:head>

<div class="flex flex-col items-center gap-6 mb-8 pt-2">
	<div class="rotate-2 rounded-2xl overflow-hidden w-28 h-28 shadow-[0_12px_32px_rgba(0,0,0,0.10)] ring-4 ring-surface">
		<Avatar
			src={data.user.avatarUrl}
			name={data.user.displayName ?? data.user.username}
			size="none"
			class="w-full h-full object-cover scale-105 rounded-none"
		/>
	</div>
	<div class="text-center">
		<h1 class="text-xl font-extrabold font-headline">{data.user.displayName ?? data.user.username}</h1>
		<p class="text-sm text-on-surface-variant">@{data.user.username}</p>
	</div>
	{#if data.user.bio}
		<p class="text-sm text-center text-on-surface-variant max-w-xs">{data.user.bio}</p>
	{/if}
	{#if data.user.location}
		<p class="text-xs text-on-surface-variant flex items-center gap-1">
			<span class="material-symbols-outlined text-base">location_on</span>
			{data.user.location}
		</p>
	{/if}
</div>

{#if status !== 'BLOCKED' && buttonLabel}
	<Button fullWidth variant={status === 'FRIENDS' ? 'secondary' : 'primary'} disabled={loading} onclick={handleFriendAction}>
		{buttonLabel}
	</Button>
{/if}
