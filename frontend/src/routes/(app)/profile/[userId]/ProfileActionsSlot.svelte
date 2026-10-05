<script lang="ts">
	// "···" menu on another user's profile (SCREENS_AND_STATES section 8.2): Block.
	// Placeholder until the social package's `$lib/components/social/ProfileActionsMenu` (Block +
	// Report) is merged: replace this component's usage in +page.svelte with that one.
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import Button from '$lib/components/ui/Button.svelte';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import { ApiRequestError } from '$lib/api/client';
	import { friendsApi } from '$lib/api/friends';
	import { errorMessage, m } from '$lib/i18n';

	interface Props {
		userId: string;
		name: string;
	}

	let { userId, name }: Props = $props();
	let menuOpen = $state(false);
	let confirmBlock = $state(false);
	let blocking = $state(false);

	async function block() {
		blocking = true;
		try {
			await friendsApi.blockUser(userId);
			toast.success(m('account.profile.blocked', { name }));
			void goto('/');
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR'));
		} finally {
			blocking = false;
			confirmBlock = false;
		}
	}
</script>

<button
	type="button"
	onclick={() => (menuOpen = true)}
	class="w-11 h-11 rounded-full bg-surface-container-high text-on-surface-variant flex items-center justify-center hover:bg-surface-container-highest flex-shrink-0"
	aria-label={m('common.moreOptions')}
	aria-haspopup="dialog"
>
	<span class="material-symbols-outlined">more_horiz</span>
</button>

{#if menuOpen}
	<BottomSheet label={m('common.moreOptions')} onClose={() => (menuOpen = false)}>
		<Button
			variant="danger"
			fullWidth
			onclick={() => {
				menuOpen = false;
				confirmBlock = true;
			}}
		>
			<span class="material-symbols-outlined text-[18px]" aria-hidden="true">block</span>
			{m('account.profile.block')}
		</Button>
	</BottomSheet>
{/if}

{#if confirmBlock}
	<ConfirmDialog
		danger
		icon="block"
		title={m('account.profile.blockTitle', { name })}
		message={m('account.profile.blockBody')}
		confirmLabel={m('account.profile.block')}
		loading={blocking}
		onConfirm={block}
		onCancel={() => (confirmBlock = false)}
	/>
{/if}
