<script lang="ts">
	import { fade, fly } from 'svelte/transition';
	import { goto } from '$app/navigation';
	import type { PageData } from './$types';
	import type { Comment, Post } from '$lib/types';
	import { postsApi } from '$lib/api/posts';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, getLocale, m } from '$lib/i18n';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ReportSheet from '$lib/components/social/ReportSheet.svelte';
	import MentionText from '$lib/components/social/MentionText.svelte';
	import PostTagsEditor from '$lib/components/social/PostTagsEditor.svelte';
	import {
		tagUpdatePayload,
		type TaggedFriend,
		type TaggedGame
	} from '$lib/components/social/postTags';
	import { displayName, timeAgo } from '$lib/components/social/format';
	import { postUrl, shareLink } from '$lib/components/social/share';
	import { toast } from 'svelte-sonner';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	const POST_EDIT_WINDOW_MS = 48 * 3600 * 1000;
	const COMMENT_EDIT_WINDOW_MS = 24 * 3600 * 1000;
	const MAX_COMMENT = 500;
	const COMMENT_PAGE_SIZE = 20;

	// Writable deriveds: follow load data, overridden locally for optimistic updates.
	let post = $derived<Post | null>(data.post);
	let comments = $derived<Comment[]>(data.comments);
	let commentsCursor = $derived<string | null>(data.commentsCursor);
	let loadingComments = $state(false);
	let commentBody = $state('');
	let submitting = $state(false);
	let activeImage = $state(0);

	let menuOpen = $state(false);
	let confirmingDelete = $state(false);
	let reportTarget = $state<{ type: 'post' | 'comment'; id: string } | null>(null);

	// Post editing
	let editCaption = $state('');
	let editLocation = $state('');
	let editGame = $state<TaggedGame | null>(null);
	let editFriends = $state<TaggedFriend[]>([]);
	let savingEdit = $state(false);

	// Comment editing
	let editingCommentId = $state<string | null>(null);
	let editCommentBody = $state('');
	let deletingComment = $state<Comment | null>(null);

	const me = $derived(data.user?.id ?? null);
	const isAuthor = $derived(post !== null && me === post.author.id);
	const canEditPost = $derived(
		isAuthor &&
			post !== null &&
			Date.now() - new Date(post.createdAt).getTime() < POST_EDIT_WINDOW_MS
	);

	// Opened from a card's "Edit post" (?edit=1); a writable derived, toggled locally
	let editing = $derived(data.editRequested && canEditPost);

	$effect(() => {
		if (editing && post) {
			editCaption = post.caption ?? '';
			editLocation = post.location ?? '';
			editGame = post.game
				? { id: post.game.id, title: post.game.title, thumbnailUrl: post.game.thumbnailUrl }
				: null;
			editFriends = post.taggedUsers.map((u) => ({ ...u }));
		}
	});

	function formatDate(iso: string) {
		return new Date(iso).toLocaleDateString(getLocale(), {
			month: 'long',
			day: 'numeric',
			year: 'numeric'
		});
	}

	function apiError(err: unknown, fallback: string) {
		toast.error(err instanceof ApiRequestError ? errorMessage(err.code) : fallback);
	}

	async function toggleLike() {
		if (!post) return;
		const was = post.likedByMe;
		post = { ...post, likedByMe: !was, likeCount: post.likeCount + (was ? -1 : 1) };
		try {
			await (was ? postsApi.unlikePost(post.id) : postsApi.likePost(post.id));
		} catch {
			post = post && { ...post, likedByMe: was, likeCount: post.likeCount + (was ? 1 : -1) };
			toast.error(m('social.post.likeFailed'));
		}
	}

	async function toggleBookmark() {
		if (!post) return;
		const was = post.isBookmarked;
		post = { ...post, isBookmarked: !was };
		try {
			await (was ? postsApi.unbookmarkPost(post.id) : postsApi.bookmarkPost(post.id));
			toast.success(m(was ? 'social.post.unsaved' : 'social.post.saved'));
		} catch {
			post = post && { ...post, isBookmarked: was };
			toast.error(m('social.post.bookmarkFailed'));
		}
	}

	async function share() {
		if (!post) return;
		const outcome = await shareLink(
			postUrl(post.id, window.location.origin),
			m('social.post.shareText')
		);
		if (outcome === 'copied') toast.success(m('social.post.linkCopied'));
		else if (outcome === 'failed') toast.error(m('social.post.shareFailed'));
	}

	async function deletePost() {
		confirmingDelete = false;
		if (!post) return;
		try {
			await postsApi.deletePost(post.id);
			toast.success(m('social.post.deleted'));
			await goto('/');
		} catch (err) {
			apiError(err, m('social.post.deleteFailed'));
		}
	}

	async function saveEdit(e: SubmitEvent) {
		e.preventDefault();
		if (!post || savingEdit) return;
		savingEdit = true;
		try {
			post = await postsApi.updatePost(post.id, {
				caption: editCaption.trim(),
				location: editLocation.trim(),
				...tagUpdatePayload(post, { game: editGame, friends: editFriends })
			});
			editing = false;
			toast.success(m('social.edit.saved'));
		} catch (err) {
			apiError(err, m('social.create.failedGeneric'));
		} finally {
			savingEdit = false;
		}
	}

	async function submitComment(e: SubmitEvent) {
		e.preventDefault();
		const body = commentBody.trim();
		if (!post || !body || submitting) return;
		submitting = true;
		try {
			const created = await postsApi.addComment(post.id, body);
			comments = [...comments, created];
			post = { ...post, commentCount: post.commentCount + 1 };
			commentBody = '';
		} catch (err) {
			apiError(err, m('social.post.commentFailed'));
		} finally {
			submitting = false;
		}
	}

	async function loadMoreComments() {
		if (!post || !commentsCursor || loadingComments) return;
		loadingComments = true;
		try {
			const page = await postsApi.getComments(post.id, commentsCursor, COMMENT_PAGE_SIZE);
			// A comment posted here meanwhile can come back in a later page: keep one copy
			const known = new Set(comments.map((c) => c.id));
			comments = [...comments, ...page.items.filter((c) => !known.has(c.id))];
			commentsCursor = page.hasMore ? page.nextCursor : null;
		} catch (err) {
			apiError(err, m('social.detail.loadCommentsFailed'));
		} finally {
			loadingComments = false;
		}
	}

	/** Mine only while my account exists: a deleted author never matches (placeholder id). */
	function isMine(c: Comment) {
		return !c.author.deleted && c.author.id === me;
	}

	function canEditComment(c: Comment) {
		return isMine(c) && Date.now() - new Date(c.createdAt).getTime() < COMMENT_EDIT_WINDOW_MS;
	}

	function startEditComment(c: Comment) {
		editingCommentId = c.id;
		editCommentBody = c.body;
	}

	async function saveComment(e: SubmitEvent) {
		e.preventDefault();
		const id = editingCommentId;
		const body = editCommentBody.trim();
		if (!post || !id || !body) return;
		try {
			const updated = await postsApi.updateComment(post.id, id, body);
			comments = comments.map((c) => (c.id === id ? updated : c));
			editingCommentId = null;
			toast.success(m('social.comment.updated'));
		} catch (err) {
			apiError(err, m('social.comment.failed'));
		}
	}

	async function deleteComment() {
		const target = deletingComment;
		deletingComment = null;
		if (!post || !target) return;
		try {
			await postsApi.deleteComment(post.id, target.id);
			comments = comments.filter((c) => c.id !== target.id);
			post = { ...post, commentCount: Math.max(0, post.commentCount - 1) };
			toast.success(m('social.comment.deleted'));
		} catch (err) {
			apiError(err, m('social.comment.failed'));
		}
	}

	function onScrollImages(e: Event) {
		const el = e.currentTarget as HTMLElement;
		activeImage = Math.round(el.scrollLeft / Math.max(el.clientWidth, 1));
	}
</script>

<svelte:head><title>{m('social.detail.title')} — Meeple</title></svelte:head>

<div class="pb-32 pt-6">
	<!-- Header -->
	<div class="mb-8 flex items-center gap-4">
		<button
			type="button"
			onclick={() => history.back()}
			aria-label={m('social.detail.back')}
			class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-all hover:text-primary active:scale-95"
		>
			<span class="material-symbols-outlined text-[20px]">arrow_back</span>
		</button>
		<h2 class="flex-1 font-headline text-xl font-black tracking-tight text-on-surface">
			{m('social.detail.title')}
		</h2>
		{#if post}
			<button
				type="button"
				onclick={share}
				aria-label={m('social.post.share')}
				class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-all hover:text-primary active:scale-95"
			>
				<span class="material-symbols-outlined text-[20px]">share</span>
			</button>
		{/if}
	</div>

	{#if !post}
		<div class="space-y-4 py-20 text-center">
			<span class="material-symbols-outlined text-5xl text-on-surface-variant/40">hide_image</span>
			<p class="font-headline text-lg font-bold text-on-surface">{m('social.detail.notFound')}</p>
			<a href="/" class="inline-block text-sm font-bold text-primary"
				>{m('social.detail.backHome')}</a
			>
		</div>
	{:else}
		<!-- Author row -->
		<div class="mb-4 flex items-center justify-between px-1">
			<div class="flex items-center gap-3">
				<Avatar
					src={post.author.deleted ? null : post.author.avatarUrl}
					name={displayName(post.author)}
					size="md"
				/>
				<div>
					{#if post.author.deleted}
						<p class="text-sm font-bold text-on-surface-variant">{displayName(post.author)}</p>
					{:else}
						<a
							href="/profile/{post.author.id}"
							class="text-sm font-bold text-on-surface hover:underline"
							>{displayName(post.author)}</a
						>
					{/if}
					<p
						class="font-label text-[10px] font-medium uppercase tracking-wider text-on-surface-variant"
					>
						{formatDate(post.createdAt)}{post.location ? ` · ${post.location}` : ''}{post.editedAt
							? ` · ${m('social.post.edited')}`
							: ''}
					</p>
				</div>
			</div>
			<div class="relative">
				<button
					type="button"
					onclick={() => (menuOpen = !menuOpen)}
					aria-label={m('social.post.more')}
					aria-haspopup="menu"
					aria-expanded={menuOpen}
					class="rounded-full p-2 text-on-surface-variant hover:bg-surface-container"
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
						class="absolute right-0 top-10 z-40 min-w-44 overflow-hidden rounded-2xl border border-white/10 bg-surface/80 py-1 shadow-[0_12px_32px_rgba(0,0,0,0.12)] backdrop-blur-xl"
					>
						{#if canEditPost}
							<button
								type="button"
								role="menuitem"
								onclick={() => {
									menuOpen = false;
									editing = true;
								}}
								class="flex w-full items-center gap-3 px-4 py-3 text-left text-sm font-semibold text-on-surface hover:bg-surface-container"
							>
								<span class="material-symbols-outlined text-[20px]">edit</span>{m(
									'social.post.edit'
								)}
							</button>
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
									reportTarget = { type: 'post', id: post?.id ?? '' };
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

		<div class="mb-6 overflow-hidden rounded-[32px] bg-surface-container-low shadow-sm">
			{#if post.imageUrls.length > 0}
				<div class="relative">
					<div
						class="hide-scrollbar flex snap-x snap-mandatory overflow-x-auto"
						onscroll={onScrollImages}
					>
						{#each post.imageUrls as url, i (i)}
							<div class="aspect-square w-full flex-shrink-0 snap-center">
								<img
									src={url}
									alt={m('social.post.image', { index: i + 1, count: post.imageUrls.length })}
									class="h-full w-full object-cover"
								/>
							</div>
						{/each}
					</div>
					{#if post.imageUrls.length > 1}
						<div
							class="pointer-events-none absolute bottom-4 left-0 right-0 flex justify-center gap-1.5"
						>
							{#each post.imageUrls as _, i (i)}
								<div
									class="h-1.5 w-1.5 rounded-full {i === activeImage ? 'bg-white' : 'bg-white/40'}"
								></div>
							{/each}
						</div>
					{/if}
				</div>
			{/if}

			<div class="space-y-4 p-5">
				<!-- Action bar -->
				<div class="flex items-center gap-5 text-on-surface-variant">
					<button
						type="button"
						onclick={toggleLike}
						aria-pressed={post.likedByMe}
						aria-label={m(post.likedByMe ? 'social.post.unlike' : 'social.post.like')}
						class="flex items-center gap-1.5 text-sm font-bold transition-all active:scale-90 {post.likedByMe
							? 'text-error'
							: 'hover:text-error'}"
					>
						<span class="material-symbols-outlined text-[24px]" class:icon-filled={post.likedByMe}
							>favorite</span
						>
						{post.likeCount}
					</button>
					<span class="flex items-center gap-1.5 text-sm font-bold">
						<span class="material-symbols-outlined text-[24px]">chat_bubble</span
						>{post.commentCount}
					</span>
					<button
						type="button"
						onclick={share}
						aria-label={m('social.post.share')}
						class="transition-all hover:text-primary active:scale-90"
					>
						<span class="material-symbols-outlined text-[24px]">share</span>
					</button>
					<button
						type="button"
						onclick={toggleBookmark}
						aria-pressed={post.isBookmarked}
						aria-label={m(post.isBookmarked ? 'social.post.unbookmark' : 'social.post.bookmark')}
						class="ml-auto transition-all active:scale-90 {post.isBookmarked
							? 'text-primary'
							: 'hover:text-primary'}"
					>
						<span
							class="material-symbols-outlined text-[24px]"
							class:icon-filled={post.isBookmarked}>bookmark</span
						>
					</button>
				</div>

				{#if post.likeCount > 0}
					<p class="font-label text-xs font-bold text-on-surface">
						{post.likeCount === 1
							? m('social.post.likeOne')
							: m('social.post.likeMany', { count: post.likeCount })}
					</p>
				{/if}

				{#if editing}
					<form onsubmit={saveEdit} class="space-y-3" transition:fade={{ duration: 150 }}>
						<label class="block space-y-1">
							<span class="font-label text-[10px] uppercase tracking-widest text-on-surface-variant"
								>{m('social.edit.caption')}</span
							>
							<textarea
								bind:value={editCaption}
								rows="4"
								maxlength="2000"
								class="w-full resize-none rounded-2xl bg-surface-container-highest px-4 py-3 text-sm text-on-surface outline-none focus:ring-2 focus:ring-primary/30"
							></textarea>
						</label>
						<label class="block space-y-1">
							<span class="font-label text-[10px] uppercase tracking-widest text-on-surface-variant"
								>{m('social.edit.location')}</span
							>
							<input
								bind:value={editLocation}
								maxlength="100"
								class="w-full rounded-2xl bg-surface-container-highest px-4 py-3 text-sm text-on-surface outline-none focus:ring-2 focus:ring-primary/30"
							/>
						</label>
						<PostTagsEditor bind:game={editGame} bind:friends={editFriends} />
						<div class="flex gap-2">
							<Button type="submit" loading={savingEdit} size="sm">{m('social.edit.save')}</Button>
							<Button variant="secondary" size="sm" onclick={() => (editing = false)}
								>{m('common.cancel')}</Button
							>
						</div>
					</form>
				{:else if post.caption}
					<p class="whitespace-pre-line text-sm leading-relaxed text-on-surface">{post.caption}</p>
				{/if}
				{#if data.editRequested && isAuthor && !canEditPost}
					<p class="text-xs text-on-surface-variant">{m('social.edit.expired')}</p>
				{/if}

				{#if post.game}
					<a
						href="/library/{post.game.id}"
						class="inline-flex items-center gap-1.5 rounded-full bg-secondary/10 px-3 py-1.5 active:scale-95"
					>
						<span class="material-symbols-outlined text-sm text-secondary">casino</span>
						<span class="font-label text-[10px] font-bold uppercase tracking-wider text-secondary"
							>{post.game.title}</span
						>
					</a>
				{/if}

				{#if post.taggedUsers.length > 0}
					<div class="flex items-center gap-2">
						<span class="font-label text-[10px] uppercase tracking-widest text-on-surface-variant"
							>{m('social.post.with')}</span
						>
						<div class="flex -space-x-2">
							{#each post.taggedUsers as tagged (tagged.id)}
								<a href="/profile/{tagged.id}" title={tagged.displayName ?? tagged.username}>
									<Avatar
										src={tagged.avatarUrl}
										name={tagged.displayName ?? tagged.username}
										size="sm"
										className="ring-2 ring-surface-container-low"
									/>
								</a>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		</div>

		<!-- Comments -->
		<section class="px-2">
			<h3
				class="mb-6 font-label text-xs font-black uppercase tracking-[0.15em] text-on-surface-variant"
			>
				{m('social.detail.commentsTitle')}
			</h3>
			{#if comments.length > 0}
				<ul class="space-y-6">
					{#each comments as comment (comment.id)}
						{@const authorName = displayName(comment.author)}
						<li class="group flex items-start gap-3">
							{#if comment.author.deleted}
								<Avatar src={null} name={authorName} size="sm" className="mt-0.5" />
							{:else}
								<a href="/profile/{comment.author.id}"
									><Avatar
										src={comment.author.avatarUrl}
										name={authorName}
										size="sm"
										className="mt-0.5"
									/></a
								>
							{/if}
							<div class="min-w-0 flex-1">
								<div class="mb-1 flex items-baseline gap-2">
									{#if comment.author.deleted}
										<span class="text-xs font-bold text-on-surface-variant">{authorName}</span>
									{:else}
										<a href="/profile/{comment.author.id}" class="text-xs font-bold text-on-surface"
											>{authorName}</a
										>
									{/if}
									<span class="font-label text-[10px] text-on-surface-variant">
										{timeAgo(comment.createdAt)}{comment.editedAt
											? ` · ${m('social.comment.edited')}`
											: ''}
									</span>
								</div>
								{#if editingCommentId === comment.id}
									<form onsubmit={saveComment} class="space-y-2">
										<textarea
											bind:value={editCommentBody}
											rows="2"
											maxlength={MAX_COMMENT}
											class="w-full resize-none rounded-2xl bg-surface-container-highest px-3 py-2 text-sm text-on-surface outline-none focus:ring-2 focus:ring-primary/30"
										></textarea>
										<div class="flex gap-3 text-xs font-bold">
											<button type="submit" class="text-primary">{m('common.save')}</button>
											<button
												type="button"
												onclick={() => (editingCommentId = null)}
												class="text-on-surface-variant">{m('common.cancel')}</button
											>
										</div>
									</form>
								{:else}
									<p class="whitespace-pre-line break-words text-sm leading-snug text-on-surface">
										<MentionText text={comment.body} />
									</p>
									<div class="mt-1 flex gap-3 text-[11px] font-semibold text-on-surface-variant">
										{#if canEditComment(comment)}
											<button
												type="button"
												onclick={() => startEditComment(comment)}
												class="hover:text-on-surface">{m('social.comment.edit')}</button
											>
										{/if}
										{#if isMine(comment) || isAuthor}
											<button
												type="button"
												onclick={() => (deletingComment = comment)}
												class="hover:text-error">{m('social.comment.delete')}</button
											>
										{/if}
										{#if !isMine(comment)}
											<button
												type="button"
												onclick={() => (reportTarget = { type: 'comment', id: comment.id })}
												class="hover:text-on-surface">{m('social.comment.report')}</button
											>
										{/if}
									</div>
								{/if}
							</div>
						</li>
					{/each}
				</ul>
				{#if commentsCursor}
					<div class="mt-6 flex justify-center">
						<Button variant="secondary" size="sm" loading={loadingComments} onclick={loadMoreComments}>
							{m('social.detail.loadMoreComments')}
						</Button>
					</div>
				{/if}
			{:else}
				<div class="py-12 text-center text-on-surface-variant">
					<span class="material-symbols-outlined mb-2 text-3xl opacity-40">forum</span>
					<p class="text-sm font-medium">{m('social.detail.noComments')}</p>
				</div>
			{/if}
		</section>
	{/if}
</div>

{#if post}
	<div
		class="fixed bottom-0 left-0 right-0 z-20 bg-gradient-to-t from-surface via-surface to-surface/0 p-4 pt-8"
		transition:fly={{ y: 20 }}
	>
		<form
			onsubmit={submitComment}
			class="mx-auto flex max-w-2xl items-center gap-3 rounded-full bg-surface-container-highest p-1.5 shadow-lg transition-shadow focus-within:ring-2 focus-within:ring-primary/40"
		>
			<input
				type="text"
				maxlength={MAX_COMMENT}
				placeholder={m('social.post.addComment')}
				aria-label={m('social.post.addComment')}
				bind:value={commentBody}
				class="flex-1 bg-transparent px-4 py-2 text-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none"
			/>
			<button
				type="submit"
				disabled={!commentBody.trim() || submitting}
				aria-label={m('social.post.postComment')}
				class="flex h-10 w-10 items-center justify-center rounded-full bg-primary text-on-primary shadow-md transition-transform active:scale-95 disabled:opacity-40"
			>
				<span class="material-symbols-outlined text-[20px]">send</span>
			</button>
		</form>
	</div>
{/if}

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

{#if deletingComment}
	<ConfirmDialog
		title={m('social.comment.deleteTitle')}
		message={m('social.comment.deleteBody')}
		confirmLabel={m('common.delete')}
		cancelLabel={m('common.cancel')}
		danger
		onConfirm={deleteComment}
		onCancel={() => (deletingComment = null)}
	/>
{/if}

{#if reportTarget}
	<ReportSheet
		targetType={reportTarget.type}
		targetId={reportTarget.id}
		title={m(
			reportTarget.type === 'post' ? 'social.report.titlePost' : 'social.report.titleComment'
		)}
		onClose={() => (reportTarget = null)}
	/>
{/if}
