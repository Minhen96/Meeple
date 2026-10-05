<script lang="ts">
	// Active sessions (SCREENS_AND_STATES section 11.4): every signed-in device, "This device",
	// per-device sign out (not for this device) and "Sign out all other devices".
	import { onMount } from 'svelte';
	import { toast } from 'svelte-sonner';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import SkeletonPattern from '$lib/components/ui/SkeletonPattern.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import { authApi } from '$lib/api/auth';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, getLocale, m } from '$lib/i18n';
	import type { SessionInfo } from '$lib/types';
	import { deviceIcon, relativeTime } from './sessions';

	let sessions = $state<SessionInfo[]>([]);
	let loading = $state(true);
	let failed = $state(false);
	let revokingId = $state<string | null>(null);
	let confirmOthers = $state(false);
	let revokingOthers = $state(false);

	const others = $derived(sessions.filter((s) => !s.current));

	async function load() {
		loading = true;
		failed = false;
		try {
			sessions = await authApi.sessions();
		} catch {
			failed = true;
		} finally {
			loading = false;
		}
	}

	onMount(load);

	async function revoke(session: SessionInfo) {
		revokingId = session.id;
		try {
			await authApi.revokeSession(session.id);
			sessions = sessions.filter((s) => s.id !== session.id);
			toast.success(m('account.sessions.signedOut'));
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR'));
		} finally {
			revokingId = null;
		}
	}

	async function revokeOthers() {
		revokingOthers = true;
		try {
			await authApi.revokeOtherSessions();
			sessions = sessions.filter((s) => s.current);
			toast.success(m('account.sessions.othersSignedOut'));
		} catch (err) {
			toast.error(errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR'));
		} finally {
			revokingOthers = false;
			confirmOthers = false;
		}
	}
</script>

<svelte:head><title>{m('account.sessions.title')} — {m('common.appName')}</title></svelte:head>

<PageHeader title={m('account.sessions.title')} />

{#if loading}
	<SkeletonPattern variant="user" count={3} />
{:else if failed}
	<div class="text-center py-12 space-y-4">
		<p class="text-sm text-on-surface-variant">{m('common.loadFailed')}</p>
		<Button variant="secondary" onclick={load}>{m('common.retry')}</Button>
	</div>
{:else}
	<ul class="space-y-2">
		{#each sessions as session (session.id)}
			<li class="flex items-center gap-3 p-4 rounded-2xl bg-surface-container-low">
				<span
					class="w-10 h-10 rounded-full bg-secondary-container text-on-secondary-container flex items-center justify-center flex-shrink-0"
				>
					<span class="material-symbols-outlined text-[20px]" aria-hidden="true">{deviceIcon(session.deviceInfo)}</span>
				</span>
				<div class="flex-1 min-w-0">
					<p class="text-sm font-bold text-on-surface truncate flex items-center gap-2">
						{session.deviceInfo || m('account.sessions.unknownDevice')}
						{#if session.current}
							<span class="text-[10px] font-label font-bold uppercase tracking-wider bg-tertiary-container text-on-tertiary-container rounded-full px-2 py-0.5">
								{m('account.sessions.thisDevice')}
							</span>
						{/if}
					</p>
					<p class="text-xs text-on-surface-variant">
						{m('account.sessions.lastActive', { time: relativeTime(session.lastUsedAt, getLocale()) })}
					</p>
				</div>
				<button
					type="button"
					disabled={session.current || revokingId === session.id}
					onclick={() => revoke(session)}
					class="text-xs font-bold px-3 py-2 rounded-full transition-colors {session.current
						? 'text-on-surface-variant/40'
						: 'text-error hover:bg-error/10'}"
				>
					{m('account.sessions.signOut')}
				</button>
			</li>
		{/each}
	</ul>

	{#if others.length > 0}
		<div class="mt-6">
			<Button variant="secondary" fullWidth onclick={() => (confirmOthers = true)}>
				{m('account.sessions.signOutOthers')}
			</Button>
		</div>
	{/if}
{/if}

{#if confirmOthers}
	<ConfirmDialog
		danger
		icon="devices"
		title={m('account.sessions.confirmTitle')}
		message={m('account.sessions.confirmBody', { count: others.length })}
		confirmLabel={m('account.sessions.signOutOthers')}
		loading={revokingOthers}
		onConfirm={revokeOthers}
		onCancel={() => (confirmOthers = false)}
	/>
{/if}
