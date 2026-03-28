<script lang="ts">
	import type { PageData } from './$types';
	import type { Comment, Post } from '$lib/types';
	import { postsApi } from '$lib/api/posts';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { toast } from 'svelte-sonner';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let post = $state<Post>(data.post);
	let comments = $state<Comment[]>(data.comments);
	let commentBody = $state('');
	let submitting = $state(false);

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

<svelte:head><title>Post — Meeple & Hearth</title></svelte:head>

<!-- Author -->
<div class="flex items-center gap-3 mb-4">
	<Avatar src={post.author.avatarUrl} name={post.author.displayName ?? post.author.username} size="sm" />
	<div>
		<p class="font-semibold text-sm">{post.author.displayName ?? post.author.username}</p>
		<p class="text-xs text-on-surface-variant">
			{#if post.game}{post.game.title} · {/if}{formatDate(post.createdAt)}
		</p>
	</div>
</div>

<!-- Images -->
{#if post.imageUrls.length > 0}
	<div class="-mx-4 mb-4">
		<img src={post.imageUrls[0]} alt="Post" class="w-full aspect-square object-cover" />
	</div>
{/if}

<!-- Like / comment actions -->
<div class="flex items-center gap-4 mb-3">
	<button
		onclick={toggleLike}
		class="flex items-center gap-1.5 text-sm font-semibold transition-colors
			{post.likedByMe ? 'text-primary' : 'text-on-surface-variant hover:text-on-surface'}"
	>
		<span class="material-symbols-outlined text-[22px]" style={post.likedByMe ? "font-variation-settings: 'FILL' 1;" : ''}>
			favorite
		</span>
		{post.likeCount}
	</button>
	<span class="flex items-center gap-1.5 text-sm text-on-surface-variant">
		<span class="material-symbols-outlined text-[22px]">chat_bubble</span>
		{post.commentCount}
	</span>
</div>

<!-- Caption -->
{#if post.caption}
	<p class="text-sm text-on-surface mb-4">{post.caption}</p>
{/if}

<!-- Comments -->
{#if comments.length > 0}
	<div class="space-y-3 mb-4">
		{#each comments as comment (comment.id)}
			<div class="flex items-start gap-2">
				<Avatar src={comment.authorAvatarUrl} name={comment.authorUsername} size="xs" />
				<div class="flex-1 bg-surface-container-low rounded-xl px-3 py-2">
					<p class="text-xs font-semibold text-on-surface">{comment.authorUsername}</p>
					<p class="text-sm text-on-surface">{comment.body}</p>
				</div>
			</div>
		{/each}
	</div>
{/if}

<!-- Add comment -->
<form onsubmit={submitComment} class="flex gap-2 items-center sticky bottom-24">
	<input
		type="text"
		placeholder="Add a comment…"
		bind:value={commentBody}
		class="flex-1 bg-surface-container-highest rounded-full px-4 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none focus:ring-2 focus:ring-primary/20"
	/>
	<button
		type="submit"
		disabled={!commentBody.trim() || submitting}
		class="w-10 h-10 rounded-full bg-primary flex items-center justify-center disabled:opacity-40"
	>
		<span class="material-symbols-outlined text-on-primary text-[18px]">send</span>
	</button>
</form>
