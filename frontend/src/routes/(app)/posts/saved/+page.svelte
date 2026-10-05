<script lang="ts">
	import { postsApi } from '$lib/api/posts';
	import { m } from '$lib/i18n';
	import PostList from '$lib/components/social/PostList.svelte';

	const fetchPage = (cursor: string | null) => postsApi.getBookmarks(cursor, 20);
</script>

<svelte:head><title>{m('social.saved.title')} — Meeple</title></svelte:head>

<div class="space-y-6 pb-32 pt-6">
	<div class="flex items-center gap-4">
		<button
			type="button"
			onclick={() => history.back()}
			aria-label={m('social.detail.back')}
			class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-all hover:text-primary active:scale-95"
		>
			<span class="material-symbols-outlined text-[20px]">arrow_back</span>
		</button>
		<h2 class="font-headline text-xl font-black tracking-tight text-on-surface">
			{m('social.saved.title')}
		</h2>
	</div>

	<!-- Un-saving a post on this page removes it from the list -->
	<PostList
		{fetchPage}
		emptyText={m('social.saved.empty')}
		dropWhen={(post) => !post.isBookmarked}
	/>
</div>
