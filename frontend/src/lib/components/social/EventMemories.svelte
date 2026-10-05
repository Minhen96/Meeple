<script lang="ts">
	import { postsApi } from '$lib/api/posts';
	import { m } from '$lib/i18n';
	import PostList from './PostList.svelte';

	/**
	 * "View Memories" for an event: posts linked to it, newest first, with a "Share a memory" link
	 * for participants. Mounted by the event detail page (events package).
	 */
	interface Props {
		eventId: string;
		/** Show the "Share a memory" button (host or accepted participant). */
		canPost?: boolean;
	}
	let { eventId, canPost = false }: Props = $props();

	const fetchPage = $derived((cursor: string | null) =>
		postsApi.getEventPosts(eventId, cursor, 20)
	);
</script>

<section class="space-y-4">
	<div class="flex items-center justify-between">
		<h3 class="font-headline text-lg font-bold">{m('social.memories.title')}</h3>
		{#if canPost}
			<a
				href="/posts/create?eventId={eventId}"
				class="inline-flex items-center gap-1 rounded-full bg-primary/10 px-4 py-1.5 font-label text-xs font-bold text-primary transition-all hover:bg-primary/20 active:scale-95"
			>
				<span class="material-symbols-outlined text-[16px]">add_a_photo</span>{m(
					'social.memories.add'
				)}
			</a>
		{/if}
	</div>
	<PostList {fetchPage} emptyText={m('social.memories.empty')} />
</section>
