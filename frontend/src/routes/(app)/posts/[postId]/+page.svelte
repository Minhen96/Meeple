<script lang="ts">
	import type { PageData } from './$types';
	import type { Comment, Post } from '$lib/types';
	import { postsApi } from '$lib/api/posts';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { toast } from 'svelte-sonner';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let post = $state<Post>(undefined!);
	let comments = $state<Comment[]>([]);
	let commentBody = $state('');
	let submitting = $state(false);

	$effect.pre(() => {
		post = data.post;
		comments = data.comments;
	});

	function formatDate(iso: string) {
		return new Date(iso).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
	}

	async function toggleLike() {
		const delta = post.likedByMe ? -1 : 1;
		post = { ...post, likedByMe: !post.likedByMe, likeCount: post.likeCount + delta };
		try {
			if (post.likedByMe) {
				await postsApi.likePost(post.id);
			} else {
				await postsApi.unlikePost(post.id);
			}
		} catch {
			post = { ...post, likedByMe: !post.likedByMe, likeCount: post.likeCount - delta };
			toast.error('Could not update like');
		}
	}

	async function submitComment(e: Event) {
		e.preventDefault();
		if (!commentBody.trim()) return;
		submitting = true;
		try {
			const newComment = await postsApi.addComment(post.id, commentBody.trim());
			comments = [...comments, newComment];
			post = { ...post, commentCount: post.commentCount + 1 };
			commentBody = '';
		} catch {
			toast.error('Could not post comment');
		} finally {
			submitting = false;
		}
	}
</script>

<svelte:head><title>Post — Meeple</title></svelte:head>

<div class="pb-32">
	<!-- Author & Post Header -->
	<div class="flex items-center justify-between mb-4">
		<div class="flex items-center gap-3">
			<Avatar src={post.author.avatarUrl} name={post.author.displayName ?? post.author.username} size="sm" />
			<div>
				<p class="font-bold text-sm text-on-surface">{post.author.displayName ?? post.author.username}</p>
				<p class="text-[10px] text-on-surface-variant uppercase tracking-wider font-medium">
					{formatDate(post.createdAt)}
				</p>
			</div>
		</div>
		{#if post.game}
			<a href="/library/{post.game.id}" class="flex items-center gap-1.5 px-3 py-1.5 bg-secondary/10 rounded-full active:scale-95 transition-transform">
				<span class="material-symbols-outlined text-sm text-secondary">casino</span>
				<span class="text-[10px] font-bold text-secondary uppercase tracking-wider">{post.game.title}</span>
			</a>
		{/if}
	</div>

	<!-- Post Content Card -->
	<div class="bg-surface-container-low rounded-[32px] overflow-hidden shadow-sm border border-surface-variant/10 mb-6">
		<!-- Images Carousel -->
		{#if post.imageUrls.length > 0}
			<div class="relative group">
				<div class="flex overflow-x-auto snap-x snap-mandatory hide-scrollbar">
					{#each post.imageUrls as url}
						<div class="flex-shrink-0 w-full aspect-square snap-center">
							<img src={url} alt="Post" class="w-full h-full object-cover" />
						</div>
					{/each}
				</div>
				{#if post.imageUrls.length > 1}
					<div class="absolute bottom-4 left-0 right-0 flex justify-center gap-1.5 pointer-events-none">
						{#each post.imageUrls as _, i}
							<div class="w-1.5 h-1.5 rounded-full bg-white/40 ring-1 ring-black/5"></div>
						{/each}
					</div>
				{/if}
			</div>
		{/if}

		<!-- Caption & Meta -->
		<div class="p-5">
			{#if post.caption}
				<p class="text-sm text-on-surface leading-relaxed mb-4">{post.caption}</p>
			{/if}

			{#if post.location}
				<p class="flex items-center gap-1 text-[11px] text-on-surface-variant mb-4">
					<span class="material-symbols-outlined text-sm">location_on</span>
					{post.location}
				</p>
			{/if}

			<div class="flex items-center justify-between pt-4 border-t border-surface-variant/20">
				<div class="flex items-center gap-6">
					<button
						onclick={toggleLike}
						class="flex items-center gap-2 text-sm font-bold transition-all active:scale-90
							{post.likedByMe ? 'text-primary' : 'text-on-surface-variant hover:text-on-surface'}"
					>
						<span class="material-symbols-outlined text-[24px]" style={post.likedByMe ? "font-variation-settings: 'FILL' 1;" : ''}>
							favorite
						</span>
						{post.likeCount}
					</button>
					<div class="flex items-center gap-2 text-sm font-bold text-on-surface-variant">
						<span class="material-symbols-outlined text-[24px]">chat_bubble</span>
						{post.commentCount}
					</div>
				</div>
				
				<button class="w-10 h-10 flex items-center justify-center text-on-surface-variant hover:text-on-surface active:scale-90">
					<span class="material-symbols-outlined text-[24px]">share</span>
				</button>
			</div>
		</div>
	</div>

	<!-- Comments Section -->
	<div class="px-2">
		<h3 class="text-xs font-black uppercase tracking-[0.15em] text-on-surface-variant mb-6">Comments</h3>
		
		{#if comments.length > 0}
			<div class="space-y-6">
				{#each comments as comment (comment.id)}
					<div class="flex items-start gap-3">
						<Avatar src={comment.authorAvatarUrl} name={comment.authorUsername} size="xs" className="mt-0.5" />
						<div class="flex-1">
							<div class="flex items-baseline justify-between gap-2 mb-1">
								<p class="text-xs font-bold text-on-surface">{comment.authorUsername}</p>
								<span class="text-[9px] text-on-surface-variant uppercase font-medium">1d ago</span>
							</div>
							<p class="text-sm text-on-surface leading-snug">{comment.body}</p>
						</div>
					</div>
				{/each}
			</div>
		{:else}
			<div class="text-center py-12 opacity-30">
				<span class="material-symbols-outlined text-3xl mb-2">forum</span>
				<p class="text-sm font-medium">No comments yet. Be the first!</p>
			</div>
		{/if}
	</div>
</div>

<!-- Sticky Comment Input -->
<div class="fixed bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-surface via-surface to-surface/0 pt-8 z-20">
	<form onsubmit={submitComment} class="max-w-2xl mx-auto flex gap-3 items-center bg-surface-container-highest rounded-full p-1.5 shadow-lg border border-surface-variant/20">
		<input
			type="text"
			placeholder="Add a comment…"
			bind:value={commentBody}
			class="flex-1 bg-transparent px-4 py-2 text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
		/>
		<button
			type="submit"
			disabled={!commentBody.trim() || submitting}
			class="w-10 h-10 rounded-full bg-primary text-on-primary flex items-center justify-center shadow-md disabled:opacity-40 active:scale-95 transition-transform"
		>
			<span class="material-symbols-outlined text-[20px]">send</span>
		</button>
	</form>
</div>
