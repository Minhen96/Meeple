<script lang="ts">
	import type { Post } from '$lib/types';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ReportSheet from './ReportSheet.svelte';
	import { postsApi } from '$lib/api/posts';
	import { currentUser } from '$lib/stores/auth';
	import { m } from '$lib/i18n';
	import { displayName, timeAgo } from './format';
	import { postUrl, shareLink } from './share';
	import { toast } from 'svelte-sonner';

	/** Feed card for a post (SCREENS_AND_STATES 7.3). Like, bookmark and comment update optimistically. */
	interface Props {
		post: Post;
		/** Called after the author deleted the post, so the list can drop it. */
		onDeleted?: (postId: string) => void;
	}
	let { post = $bindable(), onDeleted }: Props = $props();

	let quickCommentBody = $state('');
	let submittingComment = $state(false);
	let menuOpen = $state(false);
	let confirmingDelete = $state(false);
	let reporting = $state(false);
	let expanded = $state(false);
	let activeImage = $state(0);

	const isAuthor = $derived($currentUser?.id === post.author.id);
	const authorName = $derived(displayName(post.author));
	const EDIT_WINDOW_MS = 48 * 3600 * 1000;
	const canEdit = $derived(
		isAuthor && Date.now() - new Date(post.createdAt).getTime() < EDIT_WINDOW_MS
	);

	async function toggleLike() {
		const wasLiked = post.likedByMe;
		post.likedByMe = !wasLiked;
		post.likeCount += wasLiked ? -1 : 1;
		try {
			await (wasLiked ? postsApi.unlikePost(post.id) : postsApi.likePost(post.id));
		} catch {
			post.likedByMe = wasLiked;
			post.likeCount += wasLiked ? 1 : -1;
			toast.error(m('social.post.likeFailed'));
		}
	}

	async function toggleBookmark() {
		const was = post.isBookmarked;
		post.isBookmarked = !was;
		try {
			await (was ? postsApi.unbookmarkPost(post.id) : postsApi.bookmarkPost(post.id));
			toast.success(m(was ? 'social.post.unsaved' : 'social.post.saved'));
		} catch {
			post.isBookmarked = was;
			toast.error(m('social.post.bookmarkFailed'));
		}
	}

	async function share() {
		const outcome = await shareLink(postUrl(post.id, location.origin), m('social.post.shareText'));
		if (outcome === 'copied') toast.success(m('social.post.linkCopied'));
		else if (outcome === 'failed') toast.error(m('social.post.shareFailed'));
	}

	async function deletePost() {
		confirmingDelete = false;
		try {
			await postsApi.deletePost(post.id);
			toast.success(m('social.post.deleted'));
			onDeleted?.(post.id);
		} catch {
			toast.error(m('social.post.deleteFailed'));
		}
	}

	async function handleQuickComment(e: SubmitEvent) {
		e.preventDefault();
		const body = quickCommentBody.trim();
		if (!body || submittingComment) return;
		submittingComment = true;
		try {
			await postsApi.addComment(post.id, body);
			post.commentCount += 1;
			quickCommentBody = '';
			toast.success(m('social.post.commentPosted'));
		} catch {
			toast.error(m('social.post.commentFailed'));
		} finally {
			submittingComment = false;
		}
	}

	function onScrollImages(e: Event) {
		const el = e.currentTarget as HTMLElement;
		activeImage = Math.round(el.scrollLeft / Math.max(el.clientWidth, 1));
	}
</script>

<article
	class="overflow-hidden rounded-2xl bg-surface-container-lowest shadow-[0_8px_24px_rgba(0,0,0,0.04)]"
>
	<!-- Author header -->
	<div class="flex items-center gap-3 p-4">
		<Avatar src={post.author.deleted ? null : post.author.avatarUrl} name={authorName} size="sm" />
		<div class="min-w-0 flex-1">
			{#if post.author.deleted}
				<span class="text-sm font-bold text-on-surface-variant">{authorName}</span>
			{:else}
				<a
					href="/profile/{post.author.id}"
					class="text-sm font-bold text-on-surface hover:underline">{authorName}</a
				>
			{/if}
			<p class="font-label text-[10px] text-on-surface-variant">
				{timeAgo(post.createdAt)}{post.location ? ` · ${post.location}` : ''}{post.editedAt
					? ` · ${m('social.post.edited')}`
					: ''}
			</p>
		</div>
		<div class="relative">
			<button
				type="button"
				onclick={() => (menuOpen = !menuOpen)}
				class="rounded-full p-1 text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface"
				aria-label={m('social.post.more')}
				aria-haspopup="menu"
				aria-expanded={menuOpen}
			>
				<span class="material-symbols-outlined">more_horiz</span>
			</button>
			{#if menuOpen}
				<button
					type="button"
					class="fixed inset-0 z-30 cursor-default"
					aria-label={m('common.cancel')}
					onclick={() => (menuOpen = false)}
				></button>
				<div
					role="menu"
					class="absolute right-0 top-9 z-40 min-w-44 overflow-hidden rounded-2xl border border-white/10 bg-surface/80 py-1 shadow-[0_12px_32px_rgba(0,0,0,0.12)] backdrop-blur-xl"
				>
					{#if canEdit}
						<a
							role="menuitem"
							href="/posts/{post.id}?edit=1"
							class="flex items-center gap-3 px-4 py-3 text-sm font-semibold text-on-surface hover:bg-surface-container"
						>
							<span class="material-symbols-outlined text-[20px]">edit</span>{m('social.post.edit')}
						</a>
					{/if}
					{#if isAuthor}
						<button
							type="button"
							role="menuitem"
							onclick={() => {
								menuOpen = false;
								confirmingDelete = true;
							}}
							class="flex w-full items-center gap-3 px-4 py-3 text-left text-sm font-semibold text-error hover:bg-error-container/40"
						>
							<span class="material-symbols-outlined text-[20px]">delete</span>{m(
								'social.post.delete'
							)}
						</button>
					{:else}
						<button
							type="button"
							role="menuitem"
							onclick={() => {
								menuOpen = false;
								reporting = true;
							}}
							class="flex w-full items-center gap-3 px-4 py-3 text-left text-sm font-semibold text-on-surface hover:bg-surface-container"
						>
							<span class="material-symbols-outlined text-[20px]">flag</span>{m(
								'social.post.report'
							)}
						</button>
					{/if}
				</div>
			{/if}
		</div>
	</div>

	<!-- Images -->
	{#if post.imageUrls.length > 0}
		<div class="relative -mt-2">
			<div
				class="hide-scrollbar flex snap-x snap-mandatory overflow-x-auto"
				onscroll={onScrollImages}
			>
				{#each post.imageUrls as url, i (i)}
					<a
						href="/posts/{post.id}"
						class="aspect-square w-full flex-shrink-0 snap-center bg-surface-container-low"
					>
						<img
							src={url}
							alt={m('social.post.image', { index: i + 1, count: post.imageUrls.length })}
							class="h-full w-full object-cover"
							loading="lazy"
						/>
					</a>
				{/each}
			</div>
			{#if post.imageUrls.length > 1}
				<div
					class="pointer-events-none absolute bottom-4 left-0 right-0 flex justify-center gap-1.5"
				>
					{#each post.imageUrls as _, i (i)}
						<div
							class="h-1.5 w-1.5 rounded-full shadow-sm {i === activeImage
								? 'bg-white'
								: 'bg-white/40'}"
						></div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}

	<!-- Actions -->
	<div class="flex items-center gap-4 px-4 pt-3 text-on-surface-variant">
		<button
			type="button"
			onclick={toggleLike}
			class="transition-all hover:scale-105 active:scale-90 {post.likedByMe
				? 'text-error'
				: 'hover:text-error'}"
			aria-label={m(post.likedByMe ? 'social.post.unlike' : 'social.post.like')}
			aria-pressed={post.likedByMe}
		>
			<span class="material-symbols-outlined" class:icon-filled={post.likedByMe}>favorite</span>
		</button>
		<a
			href="/posts/{post.id}"
			class="transition-colors hover:text-primary"
			aria-label={m('social.post.comment')}
		>
			<span class="material-symbols-outlined">chat_bubble</span>
		</a>
		<button
			type="button"
			onclick={share}
			class="transition-all hover:scale-105 hover:text-primary active:scale-90"
			aria-label={m('social.post.share')}
		>
			<span class="material-symbols-outlined">share</span>
		</button>
		<button
			type="button"
			onclick={toggleBookmark}
			class="ml-auto transition-all hover:scale-105 active:scale-90 {post.isBookmarked
				? 'text-primary'
				: 'hover:text-primary'}"
			aria-label={m(post.isBookmarked ? 'social.post.unbookmark' : 'social.post.bookmark')}
			aria-pressed={post.isBookmarked}
		>
			<span class="material-symbols-outlined" class:icon-filled={post.isBookmarked}>bookmark</span>
		</button>
	</div>

	<!-- Text content -->
	<div class="space-y-1.5 px-4 py-3">
		{#if post.likeCount > 0}
			<p class="font-label text-xs font-bold text-on-surface">
				{post.likeCount === 1
					? m('social.post.likeOne')
					: m('social.post.likeMany', { count: post.likeCount })}
			</p>
		{/if}

		{#if post.caption}
			<p
				class="whitespace-pre-line text-sm leading-snug text-on-surface"
				class:line-clamp-3={!expanded}
			>
				<span class="font-bold">{authorName}</span>
				{post.caption}
			</p>
			{#if !expanded && post.caption.length > 140}
				<button
					type="button"
					onclick={() => (expanded = true)}
					class="text-[11px] font-semibold text-on-surface-variant"
				>
					…{m('social.post.readMore')}
				</button>
			{/if}
		{/if}

		{#if post.game}
			<p class="flex items-center gap-1 text-[11px] text-on-surface-variant">
				<span class="material-symbols-outlined text-[13px]">casino</span>
				<a href="/library/{post.game.id}" class="font-bold italic text-primary">
					{m('social.post.played', { game: post.game.title })}
				</a>
			</p>
		{/if}

		{#if post.taggedUsers.length > 0}
			<p class="text-[11px] text-on-surface-variant">
				{m('social.post.with')}:
				{#each post.taggedUsers as tagged, i (tagged.id)}<a
						href="/profile/{tagged.id}"
						class="font-semibold text-on-surface hover:underline"
						>{tagged.displayName ?? tagged.username}</a
					>{i < post.taggedUsers.length - 1 ? ', ' : ''}{/each}
			</p>
		{/if}

		{#if post.commentCount > 0}
			<a
				href="/posts/{post.id}"
				class="block pt-1 text-[11px] text-on-surface-variant transition-colors hover:text-on-surface"
			>
				{post.commentCount === 1
					? m('social.post.viewOneComment')
					: m('social.post.viewComments', { count: post.commentCount })}
			</a>
		{/if}
	</div>

	<!-- Quick comment -->
	<div class="px-4 pb-4">
		<form
			onsubmit={handleQuickComment}
			class="flex items-center gap-2 rounded-full bg-surface-container-low px-3 py-1.5 transition-shadow focus-within:ring-2 focus-within:ring-primary/40"
		>
			<input
				type="text"
				maxlength="500"
				placeholder={m('social.post.addComment')}
				aria-label={m('social.post.addComment')}
				bind:value={quickCommentBody}
				class="w-full bg-transparent p-0 text-[11px] text-on-surface outline-none placeholder:text-on-surface-variant/50 focus:ring-0"
			/>
			{#if quickCommentBody.trim()}
				<button
					type="submit"
					disabled={submittingComment}
					class="text-[11px] font-black uppercase tracking-wider text-primary transition-transform active:scale-90 disabled:opacity-50"
				>
					{m('social.post.postComment')}
				</button>
			{/if}
		</form>
	</div>
</article>

{#if confirmingDelete}
	<ConfirmDialog
		title={m('social.post.deleteTitle')}
		message={m('social.post.deleteBody')}
		confirmLabel={m('common.delete')}
		cancelLabel={m('common.cancel')}
		danger
		onConfirm={deletePost}
		onCancel={() => (confirmingDelete = false)}
	/>
{/if}

{#if reporting}
	<ReportSheet
		targetType="post"
		targetId={post.id}
		title={m('social.report.titlePost')}
		onClose={() => (reporting = false)}
	/>
{/if}
