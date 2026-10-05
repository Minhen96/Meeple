<script lang="ts">
	// Favourite games scroll + tabs Posts / Tagged / Collection (SCREENS_AND_STATES section 8.1).
	import { m, type MessageKey } from '$lib/i18n';
	import type { Post, UserGame } from '$lib/types';

	interface Props {
		posts: Post[];
		/** Posts the user was tagged in; null while that list is not available. */
		taggedPosts: Post[] | null;
		collection: UserGame[];
		/** Own profile: empty states and "See all" links address the viewer. */
		own: boolean;
		/** Other profiles: the collection is visible to friends only. */
		collectionVisible: boolean;
	}

	let { posts, taggedPosts, collection, own, collectionVisible }: Props = $props();

	type Tab = 'posts' | 'tagged' | 'collection';
	const tabs: { id: Tab; label: MessageKey; icon: string }[] = [
		{ id: 'posts', label: 'account.profileTabs.posts', icon: 'grid_on' },
		{ id: 'tagged', label: 'account.profileTabs.tagged', icon: 'sell' },
		{ id: 'collection', label: 'account.profileTabs.collection', icon: 'inventory_2' }
	];
	let active = $state<Tab>('posts');

	const favorites = $derived(collection.filter((g) => g.isFavorited));
	const owned = $derived(collection.filter((g) => g.isOwned));
	const COLLECTION_PREVIEW = 8;
</script>

{#snippet postGrid(list: Post[], empty: MessageKey)}
	{#if list.length === 0}
		<p class="text-sm text-on-surface-variant text-center py-10 bg-surface-container-low rounded-2xl">{m(empty)}</p>
	{:else}
		<div class="grid grid-cols-3 gap-1.5">
			{#each list as post (post.id)}
				<a
					href="/posts/{post.id}"
					class="aspect-square rounded-xl overflow-hidden bg-surface-container flex items-center justify-center"
					aria-label={post.caption ?? m('account.profileTabs.postLabel')}
				>
					{#if post.imageUrls.length > 0}
						<img src={post.imageUrls[0]} alt="" loading="lazy" class="w-full h-full object-cover" />
					{:else if post.game?.thumbnailUrl}
						<img src={post.game.thumbnailUrl} alt="" loading="lazy" class="w-full h-full object-cover opacity-80" />
					{:else}
						<span class="text-[11px] text-on-surface-variant p-2 line-clamp-4 text-center">{post.caption ?? ''}</span>
					{/if}
				</a>
			{/each}
		</div>
	{/if}
{/snippet}

<section class="mb-8">
	<div class="flex items-center justify-between mb-4">
		<h2 class="text-xl font-extrabold font-headline tracking-tight">{m('account.profile.favorites')}</h2>
		{#if own && favorites.length > 0}
			<a href="/library?tab=favorites" class="text-primary text-sm font-bold flex items-center gap-1">
				{m('common.seeAll')} <span class="material-symbols-outlined text-[16px]" aria-hidden="true">arrow_forward</span>
			</a>
		{/if}
	</div>
	{#if favorites.length === 0}
		<p class="text-sm text-on-surface-variant bg-surface-container-low rounded-2xl p-6 text-center">
			{own ? m('account.profile.noFavoritesOwn') : m('account.profile.noFavorites')}
		</p>
	{:else}
		<div class="flex gap-4 overflow-x-auto hide-scrollbar -mx-4 px-4 pb-3">
			{#each favorites as ug (ug.id)}
				<a href="/library/{ug.game.id}" class="flex-shrink-0 w-32 group">
					<div class="h-44 bg-surface-container rounded-2xl overflow-hidden shadow-[0_8px_24px_rgba(0,0,0,0.06)] transition-transform duration-300 group-hover:scale-[1.02]">
						{#if ug.game.thumbnailUrl}
							<img src={ug.game.thumbnailUrl} alt={ug.game.title} class="w-full h-full object-cover" loading="lazy" />
						{:else}
							<div class="w-full h-full flex items-center justify-center">
								<span class="material-symbols-outlined text-3xl text-on-surface-variant opacity-30" aria-hidden="true">casino</span>
							</div>
						{/if}
					</div>
					<p class="mt-2 text-sm font-bold text-on-surface line-clamp-1">{ug.game.title}</p>
				</a>
			{/each}
		</div>
	{/if}
</section>

<div class="flex gap-1 bg-surface-container-low rounded-full p-1 mb-4" role="tablist">
	{#each tabs as tab (tab.id)}
		<button
			type="button"
			role="tab"
			aria-selected={active === tab.id}
			onclick={() => (active = tab.id)}
			class="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-full text-xs font-bold transition-colors {active === tab.id
				? 'bg-surface-container-lowest text-primary shadow-sm'
				: 'text-on-surface-variant'}"
		>
			<span class="material-symbols-outlined text-[18px]" aria-hidden="true">{tab.icon}</span>
			{m(tab.label)}
		</button>
	{/each}
</div>

<div role="tabpanel" class="mb-8">
	{#if active === 'posts'}
		{@render postGrid(posts, own ? 'account.profileTabs.noPostsOwn' : 'account.profileTabs.noPosts')}
	{:else if active === 'tagged'}
		{#if taggedPosts === null}
			<p class="text-sm text-on-surface-variant text-center py-10 bg-surface-container-low rounded-2xl">
				{m('account.profileTabs.taggedUnavailable')}
			</p>
		{:else}
			{@render postGrid(taggedPosts, 'account.profileTabs.noTagged')}
		{/if}
	{:else if !collectionVisible}
		<p class="text-sm text-on-surface-variant text-center py-10 bg-surface-container-low rounded-2xl">
			{m('account.profileTabs.collectionFriendsOnly')}
		</p>
	{:else if owned.length === 0}
		<p class="text-sm text-on-surface-variant text-center py-10 bg-surface-container-low rounded-2xl">
			{own ? m('account.profileTabs.noCollectionOwn') : m('account.profileTabs.noCollection')}
		</p>
	{:else}
		<ul class="space-y-2">
			{#each owned.slice(0, COLLECTION_PREVIEW) as ug (ug.id)}
				<li>
					<a href="/library/{ug.game.id}" class="flex items-center gap-3 p-2 rounded-xl bg-surface-container-low hover:bg-surface-container transition-colors">
						<span class="w-12 h-12 rounded-lg overflow-hidden bg-surface-container flex-shrink-0 flex items-center justify-center">
							{#if ug.game.thumbnailUrl}
								<img src={ug.game.thumbnailUrl} alt="" class="w-full h-full object-cover" loading="lazy" />
							{:else}
								<span class="material-symbols-outlined text-on-surface-variant opacity-40" aria-hidden="true">casino</span>
							{/if}
						</span>
						<span class="flex-1 min-w-0">
							<span class="block text-sm font-bold text-on-surface truncate">{ug.game.title}</span>
							<span class="block text-xs text-on-surface-variant">{m('account.profileTabs.plays', { count: ug.playCount })}</span>
						</span>
					</a>
				</li>
			{/each}
		</ul>
		{#if own}
			<a href="/library?filter=collection" class="mt-3 text-primary text-sm font-bold flex items-center justify-center gap-1">
				{m('common.seeAll')} <span class="material-symbols-outlined text-[16px]" aria-hidden="true">arrow_forward</span>
			</a>
		{/if}
	{/if}
</div>
