<script lang="ts">
	import type { Post } from '$lib/types';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { postsApi } from '$lib/api/posts';
	import { toast } from 'svelte-sonner';

	interface Props {
		post: Post;
		onLike?: (post: Post) => void;
	}
	let { post = $bindable(), onLike }: Props = $props();

	let quickCommentBody = $state('');
	let submittingComment = $state(false);

	function formatDate(iso: string) {
		const d = new Date(iso);
		const now = new Date();
		const hrs = Math.floor((now.getTime() - d.getTime()) / 3600000);
		if (hrs < 1) return 'Just now';
		if (hrs < 24) return `${hrs}h ago`;
		return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}

	async function toggleLike() {
		const oldPost = { ...post };
		const delta = post.likedByMe ? -1 : 1;
		post.likedByMe = !post.likedByMe;
		post.likeCount += delta;

		try {
			if (oldPost.likedByMe) {
				await postsApi.unlikePost(post.id);
			} else {
				await postsApi.likePost(post.id);
			}
			onLike?.(post);
		} catch {
			post.likedByMe = oldPost.likedByMe;
			post.likeCount = oldPost.likeCount;
			toast.error('Could not update like');
		}
	}

	async function handleQuickComment(e: Event) {
		e.preventDefault();
		if (!quickCommentBody.trim() || submittingComment) return;
		submittingComment = true;
		try {
			await postsApi.addComment(post.id, quickCommentBody.trim());
			post.commentCount += 1;
			quickCommentBody = '';
			toast.success('Comment posted');
		} catch {
			toast.error('Could not post comment');
		} finally {
			submittingComment = false;
		}
	}
</script>

<article class="bg-surface-container-lowest rounded-2xl shadow-[0_8px_24px_rgba(0,0,0,0.04)] overflow-hidden border border-outline-variant/10">
	<!-- Author header -->
	<div class="p-4 flex items-center gap-3">
		<Avatar
			src={post.author.avatarUrl}
			name={post.author.displayName ?? post.author.username}
			size="sm"
			className="border border-outline-variant/30"
		/>
		<div class="flex-1 min-w-0">
			<a href="/profile/{post.author.id}" class="text-sm font-bold text-on-surface hover:underline">
				{post.author.displayName ?? post.author.username}
			</a>
			<p class="text-[10px] text-on-surface-variant font-label">
				{formatDate(post.createdAt)}{post.location ? ` · ${post.location}` : ''}
			</p>
		</div>
		<button class="text-on-surface-variant opacity-40">
			<span class="material-symbols-outlined">more_horiz</span>
		</button>
	</div>

	<!-- Images Carousel -->
	{#if post.imageUrls.length > 0}
		<div class="relative group -mt-2">
			<div class="flex overflow-x-auto snap-x snap-mandatory hide-scrollbar">
				{#each post.imageUrls as url}
					<div class="flex-shrink-0 w-full aspect-square snap-center">
						<img src={url} alt="Post" class="w-full h-full object-cover" loading="lazy" />
					</div>
				{/each}
			</div>
			{#if post.imageUrls.length > 1}
				<div class="absolute bottom-4 left-0 right-0 flex justify-center gap-1.5 pointer-events-none">
					{#each post.imageUrls as _, i}
						<div class="w-1.5 h-1.5 rounded-full bg-white/40 ring-1 ring-black/5 shadow-sm"></div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}

	<!-- Text content -->
	<div class="px-4 py-4 space-y-1.5">
		{#if post.likeCount > 0}
			<p class="text-xs font-bold text-on-surface mb-0.5">{post.likeCount} like{post.likeCount !== 1 ? 's' : ''}</p>
		{/if}

		{#if post.caption}
			<p class="text-sm text-on-surface leading-snug">
				<a href="/profile/{post.author.id}" class="font-bold hover:underline">{post.author.displayName ?? post.author.username}</a>
				{' '}{post.caption}
			</p>
		{/if}

		{#if post.game}
			<p class="text-[11px] text-on-surface-variant flex items-center gap-1 opacity-80">
				<span class="material-symbols-outlined text-[13px]">casino</span>
				Played <span class="text-primary font-bold italic">{post.game.title}</span>
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

	<!-- Actions -->
	<div class="p-4 pt-0 pb-2 flex items-center gap-4 text-on-surface-variant">
		<button
			onclick={toggleLike}
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
		<span class="material-symbols-outlined ml-auto opacity-40 text-[20px]">share</span>
	</div>

	<!-- Quick Comment Input -->
	<div class="px-4 pb-4 pt-1">
		<form onsubmit={handleQuickComment} class="flex items-center gap-2 bg-surface-container-low px-3 py-1.5 rounded-full border border-surface-variant/10">
			<input 
				type="text" 
				placeholder="Add a comment..." 
				bind:value={quickCommentBody}
				class="bg-transparent text-[11px] w-full outline-none text-on-surface border-none p-0 focus:ring-0 placeholder:text-on-surface-variant/30"
			/>
			{#if quickCommentBody.trim()}
				<button 
					type="submit" 
					disabled={submittingComment}
					class="text-[11px] font-black text-primary uppercase tracking-wider active:scale-90 transition-transform disabled:opacity-50"
				>
					Post
				</button>
			{/if}
		</form>
	</div>
</article>

<style>
	.hide-scrollbar::-webkit-scrollbar {
		display: none;
	}
	.hide-scrollbar {
		-ms-overflow-style: none;
		scrollbar-width: none;
	}
</style>
