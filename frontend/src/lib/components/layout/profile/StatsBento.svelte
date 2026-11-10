<script lang="ts">
	// Stats bento (SCREENS_AND_STATES section 8.1; FEATURES_COMPLETE section 9.1): Games Owned |
	// Sessions (emphasised) | Friends, then the highlights when the stats endpoint provides them.
	import { m } from '$lib/i18n';
	import type { BentoStats } from './profileStats';

	interface Props {
		stats: BentoStats;
		/** Link for the Friends card (own profile). */
		friendsHref?: string;
	}

	let { stats, friendsHref }: Props = $props();
	const hasHighlights = $derived(Boolean(stats.mostPlayedGame || stats.favoriteCategory || stats.mostPlayedWith));
	// md+: the bento sits inside the tonal profile banner, so its cards lift to the lowest surface.
	const card = 'bg-surface-container-low md:bg-surface-container-lowest p-4 rounded-2xl text-center';
	const highlight = 'flex items-center gap-3 bg-surface-container-low md:bg-surface-container-lowest rounded-xl px-4 py-3';
</script>

<div class="grid grid-cols-3 gap-3 mb-4 {hasHighlights ? 'md:mb-3' : 'md:mb-0'}">
	<div class={card}>
		<p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant opacity-70 mb-1">
			{m('account.stats.owned')}
		</p>
		<p class="text-2xl font-extrabold font-headline">{stats.gamesOwned}</p>
	</div>
	<div class="bg-primary/10 p-4 rounded-2xl text-center">
		<p class="font-label text-[10px] font-bold uppercase tracking-widest text-primary opacity-80 mb-1">
			{m('account.stats.sessions')}
		</p>
		<p class="text-2xl font-extrabold font-headline">{stats.sessions}</p>
	</div>
	{#if friendsHref}
		<a href={friendsHref} class="{card} block hover:bg-surface-container md:hover:bg-surface-container-high transition-colors">
			<p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant opacity-70 mb-1">
				{m('account.stats.friends')}
			</p>
			<p class="text-2xl font-extrabold font-headline">{stats.friends ?? '–'}</p>
		</a>
	{:else}
		<div class={card}>
			<p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant opacity-70 mb-1">
				{m('account.stats.friends')}
			</p>
			<p class="text-2xl font-extrabold font-headline">{stats.friends ?? '–'}</p>
		</div>
	{/if}
</div>

{#if hasHighlights}
	<ul class="mb-8 md:mb-0 space-y-2 text-sm">
		{#if stats.mostPlayedGame}
			<li class={highlight}>
				<span class="material-symbols-outlined text-primary text-[20px]" aria-hidden="true">trophy</span>
				<a href="/library/{stats.mostPlayedGame.gameId}" class="flex-1 text-on-surface hover:text-primary">
					{m('account.stats.mostPlayed', { game: stats.mostPlayedGame.title, count: stats.mostPlayedGame.playCount })}
				</a>
			</li>
		{/if}
		{#if stats.favoriteCategory}
			<li class={highlight}>
				<span class="material-symbols-outlined text-secondary text-[20px]" aria-hidden="true">category</span>
				<span class="flex-1 text-on-surface">{m('account.stats.favoriteCategory', { category: stats.favoriteCategory })}</span>
			</li>
		{/if}
		{#if stats.mostPlayedWith}
			<li class={highlight}>
				<span class="material-symbols-outlined text-tertiary text-[20px]" aria-hidden="true">group</span>
				<a href="/profile/{stats.mostPlayedWith.userId}" class="flex-1 text-on-surface hover:text-primary">
					{m('account.stats.mostPlayedWith', {
						name: stats.mostPlayedWith.displayName,
						count: stats.mostPlayedWith.sharedSessions
					})}
				</a>
			</li>
		{/if}
	</ul>
{:else}
	<div class="mb-8 md:hidden"></div>
{/if}
