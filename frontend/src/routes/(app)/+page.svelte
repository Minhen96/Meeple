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
			posts = posts.map((p) =>
				p.id === post.id ? { ...p, likedByMe: post.likedByMe, likeCount: post.likeCount } : p
			);
			toast.error('Could not update like');
		}
	}

	function formatEventDay(iso: string) {
		return new Date(iso).toLocaleDateString('en-US', { weekday: 'short' }).toUpperCase();
	}

	function formatEventDate(iso: string) {
		return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}

	function formatPostTime(iso: string) {
		const d = new Date(iso);
		const now = new Date();
		const hrs = Math.floor((now.getTime() - d.getTime()) / 3600000);
		if (hrs < 1) return 'Just now';
		if (hrs < 24) return `${hrs}h ago`;
		return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}
</script>

<svelte:head>
	<title>Home — Meeple</title>
</svelte:head>

<div class="space-y-8">
	<!-- Greeting -->
	<section class="space-y-1">
		<h2 class="text-3xl font-headline font-extrabold tracking-tight text-on-surface">
			{greeting}, <span class="text-primary">{data.user?.displayName ?? data.user?.username ?? 'there'}</span>!
		</h2>
		<p class="text-on-surface-variant font-medium text-sm">
			{#if data.upcomingEvents.length > 0}
				You have {data.upcomingEvents.length} upcoming event{data.upcomingEvents.length !== 1 ? 's' : ''}.
			{:else}
				No upcoming events — create one!
			{/if}
		</p>
	</section>

	<!-- Match suggestions -->
	{#if matchSuggestions.length > 0}
		<section class="space-y-3">
			{#each matchSuggestions as group (group.id)}
				<MatchSuggestionCard {group} onDismiss={onGroupDismiss} />
			{/each}
		</section>
	{/if}

	<!-- Upcoming Events carousel -->
	{#if data.upcomingEvents.length > 0}
		<section class="space-y-4">
			<div class="flex justify-between items-center">
				<h3 class="text-lg font-headline font-bold">Upcoming Events</h3>
				<a href="/events" class="text-primary text-xs font-label font-bold uppercase tracking-widest">View All</a>
			</div>
			<div class="flex gap-3 overflow-x-auto hide-scrollbar -mx-4 px-4 pb-1">
				{#each data.upcomingEvents.slice(0, 6) as event}
					<a
						href="/events/{event.id}"
						class="flex-shrink-0 w-56 bg-surface-container-low rounded-xl p-4 shadow-sm spring-bounce"
					>
						<div class="flex justify-between items-start mb-3">
							<span class="bg-secondary-container text-on-secondary-container px-2 py-0.5 rounded text-[10px] font-label font-bold uppercase tracking-tight">
								{formatEventDay(event.scheduledAt)}
							</span>
							<span class="text-[10px] font-label text-on-surface-variant">{formatEventDate(event.scheduledAt)}</span>
						</div>
						<h4 class="font-bold text-sm text-on-surface line-clamp-1 mb-1">{event.title}</h4>
						{#if event.location}
							<p class="text-xs text-on-surface-variant flex items-center gap-1 mb-3">
								<span class="material-symbols-outlined text-[13px]">location_on</span>
								<span class="line-clamp-1">{event.location}</span>
							</p>
						{:else}
							<div class="mb-3"></div>
						{/if}
						<div class="flex items-center justify-between">
							<span class="text-[10px] font-label font-bold text-on-surface-variant">
								{event.participantCount}/{event.maxParticipants} players
							</span>
							{#if event.status === 'FULL'}
								<span class="text-[10px] font-label font-bold text-error">Full</span>
							{:else}
								<span class="text-[10px] font-label font-bold text-tertiary">Open</span>
							{/if}
						</div>
					</a>
				{/each}
			</div>
		</section>
	{/if}

	<!-- Activity Feed -->
	<section class="space-y-4">
		<div class="flex justify-between items-center">
			<h3 class="text-lg font-headline font-bold">Activity Feed</h3>
			<span class="material-symbols-outlined text-on-surface-variant">tune</span>
		</div>

		{#if posts.length === 0}
			<div class="text-center py-16 text-on-surface-variant">
				<span class="material-symbols-outlined text-5xl mb-3 block opacity-40">feed</span>
				<p class="font-semibold">Nothing here yet</p>
				<p class="text-sm mt-1">Be the first to share a game session!</p>
			</div>
		{:else}
			<div class="space-y-4">
				{#each posts as post (post.id)}
					<article class="bg-white rounded-2xl shadow-sm overflow-hidden">
						<!-- Author header -->
						<div class="p-4 flex items-center gap-3">
							<Avatar
								src={post.author.avatarUrl}
								name={post.author.displayName ?? post.author.username}
								size="sm"
							/>
							<div class="flex-1 min-w-0">
								<p class="text-sm font-bold text-on-surface">
									{post.author.displayName ?? post.author.username}
								</p>
								<p class="text-[10px] text-on-surface-variant font-label">
									{formatPostTime(post.createdAt)}{post.location ? ` · ${post.location}` : ''}
								</p>
							</div>
							<button class="text-on-surface-variant opacity-40">
								<span class="material-symbols-outlined">more_horiz</span>
							</button>
						</div>

						<!-- Image -->
						{#if post.imageUrls.length > 0}
							<div class="aspect-square bg-surface-container-low overflow-hidden">
								<img
									src={post.imageUrls[0]}
									alt="Session photo"
									class="w-full h-full object-cover"
									loading="lazy"
								/>
							</div>
						{/if}

						<!-- Actions + caption -->
						<div class="p-4 space-y-2">
							<div class="flex items-center gap-4 text-on-surface-variant">
								<button
									onclick={() => toggleLike(post)}
									class="transition-colors {post.likedByMe ? 'text-error' : 'hover:text-error'}"
									aria-label="Like"
								>
									<span
										class="material-symbols-outlined"
										style={post.likedByMe ? "font-variation-settings: 'FILL' 1;" : ''}
									>favorite</span>
								</button>
								<a href="/posts/{post.id}" class="hover:text-primary transition-colors" aria-label="Comment">
									<span class="material-symbols-outlined">chat_bubble</span>
								</a>
								<span class="material-symbols-outlined ml-auto opacity-40">share</span>
							</div>

							{#if post.likeCount > 0}
								<p class="text-xs font-bold text-on-surface">{post.likeCount} like{post.likeCount !== 1 ? 's' : ''}</p>
							{/if}

							{#if post.caption}
								<p class="text-sm text-on-surface">
									<span class="font-bold">{post.author.displayName ?? post.author.username}</span>
									{' '}{post.caption}
								</p>
							{/if}

							{#if post.game}
								<p class="text-xs text-on-surface-variant">
									Played <span class="text-primary font-semibold italic">{post.game.title}</span>
								</p>
							{/if}

							{#if post.commentCount > 0}
								<div class="pt-1">
									<a href="/posts/{post.id}" class="text-[11px] text-on-surface-variant hover:text-on-surface transition-colors">
										View all {post.commentCount} comment{post.commentCount !== 1 ? 's' : ''}
									</a>
								</div>
							{/if}
						</div>
					</article>
				{/each}
			</div>
		{/if}
	</section>
</div>
