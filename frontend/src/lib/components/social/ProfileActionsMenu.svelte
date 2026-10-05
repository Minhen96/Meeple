<script lang="ts">
	import { fade, scale } from 'svelte/transition';
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ReportSheet from './ReportSheet.svelte';
	import { toast } from 'svelte-sonner';

	/**
	 * The "···" menu on another user's profile (SCREENS_AND_STATES 8.2): Block / Unblock and Report.
	 * Mounted by the profile page (`routes/(app)/profile/[userId]`, owned by the account package).
	 * Blocking is silent for the other user and removes the friendship server-side; the page decides
	 * what to do next via `onBlocked` (for example navigate back, since the profile becomes a 404).
	 */
	interface Props {
		userId: string;
		/** Display name used in the confirmation and toasts. */
		name: string;
		/** Whether the viewer has already blocked this user (FriendStatus 'BLOCKED'). */
		blocked?: boolean;
		onBlocked?: () => void;
		onUnblocked?: () => void;
	}

	let { userId, name, blocked = $bindable(false), onBlocked, onUnblocked }: Props = $props();

	let open = $state(false);
	let confirmingBlock = $state(false);
	let reporting = $state(false);
	let busy = $state(false);

	function choose(action: () => void) {
		open = false;
		action();
	}

	async function block() {
		confirmingBlock = false;
		if (busy) return;
		busy = true;
		try {
			await friendsApi.blockUser(userId);
			blocked = true;
			toast.success(m('social.menu.blocked', { name }));
			onBlocked?.();
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : null));
		} finally {
			busy = false;
		}
	}

	async function unblock() {
		if (busy) return;
		busy = true;
		try {
			await friendsApi.unblockUser(userId);
			blocked = false;
			toast.success(m('social.menu.unblocked', { name }));
			onUnblocked?.();
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : null));
		} finally {
			busy = false;
		}
	}

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') open = false;
	}
</script>

<svelte:window onkeydown={onKeydown} />

<div class="relative">
	<button
		type="button"
		onclick={() => (open = !open)}
		disabled={busy}
		aria-haspopup="menu"
		aria-expanded={open}
		aria-label={m('social.menu.label')}
		class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-all hover:scale-105 hover:text-on-surface active:scale-95 disabled:opacity-50"
	>
		<span class="material-symbols-outlined">more_horiz</span>
	</button>

	{#if open}
		<button
			type="button"
			class="fixed inset-0 z-40 cursor-default"
			aria-label={m('common.cancel')}
			onclick={() => (open = false)}
			transition:fade={{ duration: 100 }}
		></button>
		<div
			role="menu"
			class="absolute right-0 top-12 z-50 min-w-44 overflow-hidden rounded-2xl border border-white/10 bg-surface/80 py-1 shadow-[0_12px_32px_rgba(0,0,0,0.12)] backdrop-blur-xl"
			transition:scale={{ duration: 150, start: 0.95 }}
		>
			{#if blocked}
				<button
					type="button"
					role="menuitem"
					onclick={() => choose(unblock)}
					class="flex w-full items-center gap-3 px-4 py-3 text-left text-sm font-semibold text-on-surface hover:bg-surface-container"
				>
					<span class="material-symbols-outlined text-[20px]">lock_open</span>{m(
						'social.menu.unblock'
					)}
				</button>
			{:else}
				<button
					type="button"
					role="menuitem"
					onclick={() => choose(() => (confirmingBlock = true))}
					class="flex w-full items-center gap-3 px-4 py-3 text-left text-sm font-semibold text-error hover:bg-error-container/40"
				>
					<span class="material-symbols-outlined text-[20px]">block</span>{m('social.menu.block')}
				</button>
			{/if}
			<button
				type="button"
				role="menuitem"
				onclick={() => choose(() => (reporting = true))}
				class="flex w-full items-center gap-3 px-4 py-3 text-left text-sm font-semibold text-on-surface hover:bg-surface-container"
			>
				<span class="material-symbols-outlined text-[20px]">flag</span>{m('social.menu.report')}
			</button>
		</div>
	{/if}
</div>

{#if confirmingBlock}
	<ConfirmDialog
		title={m('social.menu.blockTitle', { name })}
		message={m('social.menu.blockBody')}
		confirmLabel={m('social.menu.block')}
		cancelLabel={m('common.cancel')}
		danger
		onConfirm={block}
		onCancel={() => (confirmingBlock = false)}
	/>
{/if}

{#if reporting}
	<ReportSheet
		targetType="user"
		targetId={userId}
		title={m('social.report.titleUser', { name })}
		onClose={() => (reporting = false)}
	/>
{/if}
