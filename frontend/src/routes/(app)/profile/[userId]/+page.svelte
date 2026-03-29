<script lang="ts">
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import { friendsApi } from '$lib/api/friends';
	import type { FriendStatusValue } from '$lib/types';

	let { data } = $props();

	let status = $state<FriendStatusValue>(data.friendStatus.status);
	let requestId = $state<string | null>(data.friendStatus.requestId);
	let loading = $state(false);

	async function handleFriendAction() {
		loading = true;
		try {
			if (status === 'NONE') {
				const req = await friendsApi.sendRequest(data.user.id);
				requestId = req.id;
				status = 'PENDING_SENT';
			} else if (status === 'PENDING_SENT' && requestId) {
				// Cancel — not implemented in API yet, show nothing
			} else if (status === 'PENDING_RECEIVED' && requestId) {
				await friendsApi.accept(requestId);
				status = 'FRIENDS';
			} else if (status === 'FRIENDS') {
				await friendsApi.unfriend(data.user.id);
				status = 'NONE';
				requestId = null;
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

<svelte:head><title>{data.user.displayName ?? data.user.username} — Meeple & Hearth</title></svelte:head>

<div class="flex flex-col items-center gap-3 mb-6">
	<Avatar src={data.user.avatarUrl} size="lg" />
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
