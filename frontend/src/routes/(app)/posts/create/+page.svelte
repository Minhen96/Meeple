<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import { postsApi } from '$lib/api/posts';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';

	let caption = $state('');
	let loading = $state(false);
	let error = $state('');

	// Image upload is a two-step process:
	// 1. GET presigned URL from backend → PUT image directly to R2
	// 2. POST post with the returned R2 key
	// For Phase 1: posts without images are supported; image upload requires R2 setup.
	// We keep the image UI as a placeholder.

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!caption.trim()) {
			error = 'Please write a caption.';
			return;
		}
		error = '';
		loading = true;
		try {
			const post = await postsApi.createPost({ caption: caption.trim() });
			toast.success('Posted!');
			goto(`/posts/${post.id}`);
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = 'Something went wrong.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Post — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">New Post</h2>

<form onsubmit={handleSubmit} class="space-y-5 pb-28">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<!-- Image placeholder (requires R2 presign flow — Phase 1 text-only) -->
	<div class="border-2 border-dashed border-outline-variant/30 rounded-xl p-8 flex flex-col items-center gap-3 text-on-surface-variant opacity-50">
		<span class="material-symbols-outlined text-4xl">add_photo_alternate</span>
		<p class="text-sm">Image upload coming soon</p>
	</div>

	<!-- Caption -->
	<textarea
		rows="4"
		placeholder="What happened at the table?"
		bind:value={caption}
		required
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
	></textarea>

	<!-- Submit -->
	<div class="fixed bottom-0 left-0 right-0 bg-background/80 backdrop-blur-xl px-4 py-4 max-w-lg mx-auto">
		<Button type="submit" fullWidth {loading}>Post</Button>
	</div>
</form>
