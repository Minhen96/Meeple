<script lang="ts">
	import { getGreeting } from '$lib/utils/date';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import MatchSuggestionCard from '$lib/components/match/MatchSuggestionCard.svelte';
	import type { PageData } from './$types';
	import type { Post } from '$lib/types';
	import { postsApi } from '$lib/api/posts';
	import { toast } from 'svelte-sonner';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const greeting = getGreeting();

	let posts = $state(data.posts);
	let matchSuggestions = $state(data.matchSuggestions);

	function onGroupDismiss(id: string) {
		matchSuggestions = matchSuggestions.filter((g) => g.id !== id);
	}

	async function toggleLike(post: Post) {
		// Optimistic update — like/unlike return 204 void
		const delta = post.likedByMe ? -1 : 1;
		posts = posts.map((p) =>
			p.id === post.id ? { ...p, likedByMe: !p.likedByMe, likeCount: p.likeCount + delta } : p
		);
		try {
			if (post.likedByMe) {
				await postsApi.unlikePost(post.id);
			} else {
				await postsApi.likePost(post.id);
			}
		} catch {
			// Rollback
			posts = posts.map((p) =>
				p.id === post.id ? { ...p, likedByMe: post.likedByMe, likeCount: post.likeCount } : p
			);
			toast.error('Could not update like');
		}
	}

	function formatDate(iso: string) {
		return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}
</script>

<svelte:head>
	<title>Home — Meeple & Hearth</title>
</svelte:head>

<!-- Greeting -->
<section class="space-y-1 mb-6">
	<h2 class="text-3xl font-extrabold tracking-tight font-headline text-on-surface">
		{greeting}, {data.user?.displayName ?? data.user?.username ?? 'there'}!
	</h2>
	{#if data.upcomingEvents.length > 0}
		<p class="text-sm text-on-surface-variant">
			{data.upcomingEvents.length} upcoming event{data.upcomingEvents.length !== 1 ? 's' : ''}
		</p>
	{:else}
		<p class="text-sm text-on-surface-variant">No upcoming events.</p>
	{/if}
</section>

<!-- Upcoming events strip -->
{#if data.upcomingEvents.length > 0}
	<div class="flex gap-3 overflow-x-auto hide-scrollbar mb-6 pb-1">
		{#each data.upcomingEvents.slice(0, 5) as event}
			<a
				href="/events/{event.id}"
				class="flex-shrink-0 bg-primary/10 rounded-xl p-3 w-48 space-y-1"
			>
				<p class="text-xs font-label font-bold text-primary uppercase tracking-wide">
					{new Date(event.scheduledAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
				</p>
				<p class="text-sm font-semibold text-on-surface line-clamp-1">{event.title}</p>
				<p class="text-xs text-on-surface-variant">
					{event.participantCount}/{event.maxParticipants} players
				</p>
			</a>
		{/each}
	</div>
{/if}

<!-- Match suggestions -->
{#if matchSuggestions.length > 0}
	<section class="space-y-3 mb-6">
		{#each matchSuggestions as group (group.id)}
			<MatchSuggestionCard {group} onDismiss={onGroupDismiss} />
		{/each}
	</section>
{/if}

<!-- Feed -->
{#if posts.length === 0}
	<div class="text-center py-16 text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl mb-3 block opacity-40">feed</span>
		<p class="font-semibold">Nothing here yet</p>
		<p class="text-sm mt-1">Be the first to share a game session!</p>
	</div>
{:else}
	<section class="space-y-4">
		{#each posts as post (post.id)}
			<article class="bg-surface-container-lowest rounded-xl shadow-[0_12px_32px_rgba(25,28,29,0.06)] overflow-hidden">
				<!-- Author header -->
				<div class="flex items-center gap-3 p-4 pb-3">
					<Avatar src={post.author.avatarUrl} name={post.author.displayName ?? post.author.username} size="sm" />
					<div class="flex-1 min-w-0">
						<p class="font-semibold text-sm text-on-surface">
							{post.author.displayName ?? post.author.username}
						</p>
						<p class="text-xs text-on-surface-variant">
							{#if post.game}
								Played {post.game.title} · {formatDate(post.createdAt)}
							{:else}
								{formatDate(post.createdAt)}
							{/if}
						</p>
					</div>
				</div>

				<!-- Images -->
				{#if post.imageUrls.length > 0}
					<img
						src={post.imageUrls[0]}
						alt="Post image"
						class="w-full aspect-square object-cover"
						loading="lazy"
					/>
				{/if}

				<!-- Caption -->
				{#if post.caption}
					<p class="px-4 pt-3 text-sm text-on-surface">{post.caption}</p>
				{/if}

				<!-- Actions -->
				<div class="flex items-center gap-4 px-4 py-3">
					<button
						onclick={() => toggleLike(post)}
						class="flex items-center gap-1.5 text-sm font-semibold transition-colors {post.likedByMe
							? 'text-primary'
							: 'text-on-surface-variant hover:text-on-surface'}"
					>
						<span class="material-symbols-outlined text-[20px]" style={post.likedByMe ? "font-variation-settings: 'FILL' 1;" : ''}>
							favorite
						</span>
						{post.likeCount}
					</button>
					<a
						href="/posts/{post.id}"
						class="flex items-center gap-1.5 text-sm font-semibold text-on-surface-variant hover:text-on-surface transition-colors"
					>
						<span class="material-symbols-outlined text-[20px]">chat_bubble</span>
						{post.commentCount}
					</a>
				</div>
			</article>
		{/each}
	</section>
{/if}
