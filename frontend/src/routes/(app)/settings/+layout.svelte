<script lang="ts">
	// Settings shell (SCREENS_AND_STATES sections 11.1 and 16). Phones keep page-per-screen
	// navigation: /settings is the menu, each sub-screen replaces it. From lg the menu is a
	// persistent left column and the selected screen renders on the right; the sub-screens' own
	// back buttons (data-settings-back) are hidden there because the menu is always in view.
	import { tick } from 'svelte';
	import { page } from '$app/state';
	import PageContainer from '$lib/components/layout/PageContainer.svelte';
	import SettingsMenu from '$lib/components/settings/SettingsMenu.svelte';
	import { isSettingsRoot } from '$lib/components/settings/settingsNav';
	import { m } from '$lib/i18n';
	import { LG_QUERY, matchesMedia } from '$lib/utils/media';

	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();

	const atRoot = $derived(isSettingsRoot(page.url.pathname));

	let menu = $state<HTMLElement>();

	// lg: the menu column scrolls on its own; keep the highlighted row in view after navigating.
	$effect(() => {
		void page.url.pathname;
		if (!menu || !matchesMedia(LG_QUERY)) return;
		const container = menu;
		void tick().then(() => {
			const row = container.querySelector<HTMLElement>('[aria-current="page"]');
			if (!row) return;
			const top = row.getBoundingClientRect().top - container.getBoundingClientRect().top + container.scrollTop;
			const bottom = top + row.offsetHeight;
			if (top < container.scrollTop || bottom > container.scrollTop + container.clientHeight) {
				container.scrollTop = Math.max(0, top - container.clientHeight / 2);
			}
		});
	});
</script>

<PageContainer width="full" class="md:max-w-xl lg:max-w-5xl">
	<div
		class="lg:grid lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-8 xl:grid-cols-[19rem_minmax(0,1fr)] xl:gap-12 lg:items-start"
	>
		<aside
			bind:this={menu}
			aria-label={m('account.settings.title')}
			class="{atRoot
				? ''
				: 'hidden lg:block'} lg:sticky lg:top-4 lg:max-h-[calc(100vh-2rem)] lg:overflow-y-auto lg:-mx-1 lg:px-1 lg:pb-6 hide-scrollbar"
		>
			<div class="flex items-center gap-3 mb-8 mt-3">
				<a
					href="/profile"
					class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
					aria-label={m('common.back')}
				>
					<span class="material-symbols-outlined text-[22px]">arrow_back</span>
				</a>
				<h2 class="text-2xl font-extrabold font-headline">{m('account.settings.title')}</h2>
			</div>
			<SettingsMenu />
		</aside>

		<div class="min-w-0 {atRoot ? 'hidden lg:block' : ''} lg:[&_[data-settings-back]]:hidden">
			{@render children?.()}
		</div>
	</div>
</PageContainer>
