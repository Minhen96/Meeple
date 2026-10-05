<script lang="ts">
	// Own profile (SCREENS_AND_STATES section 8.1): hero, stats bento, Edit Profile + "···"
	// (Share profile, Settings, Log out), favourites and Posts / Tagged / Collection tabs.
	import { goto, invalidateAll } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import Button from '$lib/components/ui/Button.svelte';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import PullToRefresh from '$lib/components/ui/PullToRefresh.svelte';
	import ProfileHero from '$lib/components/layout/profile/ProfileHero.svelte';
	import StatsBento from '$lib/components/layout/profile/StatsBento.svelte';
	import ProfileContent from '$lib/components/layout/profile/ProfileContent.svelte';
	import { bentoStats } from '$lib/components/layout/profile/profileStats';
	import { logout } from '$lib/session';
	import { m } from '$lib/i18n';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	let menuOpen = $state(false);
	const stats = $derived(bentoStats(data.stats, data.collection, data.friendCount));

	async function share() {
		menuOpen = false;
		const url = `${window.location.origin}/profile/${data.user.id}`;
		try {
			if (navigator.share) {
				await navigator.share({ title: data.user.displayName ?? data.user.username, url });
			} else {
				await navigator.clipboard.writeText(url);
				toast.success(m('common.linkCopied'));
			}
		} catch {
			// share sheet dismissed
		}
	}

	async function handleLogout() {
		menuOpen = false;
		await logout();
		void goto('/auth/login');
	}
</script>

<svelte:head><title>{m('common.nav.profile')} — {m('common.appName')}</title></svelte:head>

<PullToRefresh onRefresh={() => invalidateAll()}>
	<ProfileHero user={data.user}>
		{#snippet actions()}
			<div class="flex gap-2 w-full max-w-xs">
				<a
					href="/settings/profile"
					class="flex-1 inline-flex items-center justify-center gap-2 rounded-full py-2.5 px-5 text-sm font-headline font-bold bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest transition-colors"
				>
					<span class="material-symbols-outlined text-[18px]" aria-hidden="true">edit</span>
					{m('account.profile.edit')}
				</a>
				<button
					type="button"
					onclick={() => (menuOpen = true)}
					class="w-11 h-11 rounded-full bg-surface-container-high text-on-surface-variant flex items-center justify-center hover:bg-surface-container-highest"
					aria-label={m('common.moreOptions')}
					aria-haspopup="dialog"
				>
					<span class="material-symbols-outlined">more_horiz</span>
				</button>
			</div>
		{/snippet}
	</ProfileHero>

	<StatsBento {stats} friendsHref="/profile/friends" />

	<ProfileContent
		posts={data.posts}
		taggedPosts={data.taggedPosts}
		collection={data.collection}
		own
		collectionVisible
	/>
</PullToRefresh>

{#if menuOpen}
	<BottomSheet label={m('common.moreOptions')} onClose={() => (menuOpen = false)}>
		<div class="flex flex-col gap-2">
			<Button variant="secondary" fullWidth onclick={share}>
				<span class="material-symbols-outlined text-[18px]" aria-hidden="true">share</span>
				{m('account.profile.share')}
			</Button>
			<Button variant="secondary" fullWidth onclick={() => { menuOpen = false; void goto('/settings'); }}>
				<span class="material-symbols-outlined text-[18px]" aria-hidden="true">settings</span>
				{m('account.settings.title')}
			</Button>
			<Button variant="danger" fullWidth onclick={handleLogout}>
				<span class="material-symbols-outlined text-[18px]" aria-hidden="true">logout</span>
				{m('account.settings.logout')}
			</Button>
		</div>
	</BottomSheet>
{/if}
