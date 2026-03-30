<script lang="ts">
	import { postsApi } from '$lib/api/posts';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';

	let caption = $state('');
	let loading = $state(false);
	let error = $state('');

	// Quick tag chips
	const quickTags = ['#GameNight', '#VictoryRoyale', '#TableTopLife', '#BoardGames', '#NewToMe'];
	let selectedTags = $state<string[]>([]);

	function toggleTag(tag: string) {
		selectedTags = selectedTags.includes(tag)
			? selectedTags.filter((t) => t !== tag)
			: [...selectedTags, tag];
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!caption.trim()) {
			error = 'Please write something.';
			return;
		}
		error = '';
		loading = true;
		const fullCaption = selectedTags.length
			? `${caption.trim()} ${selectedTags.join(' ')}`
			: caption.trim();
		try {
			const post = await postsApi.createPost({ caption: fullCaption });
			toast.success('Posted!');
			goto(`/posts/${post.id}`);
		} catch (err) {
			error = err instanceof ApiRequestError ? err.message : 'Something went wrong.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Post — Meeple & Hearth</title></svelte:head>

<div class="flex items-center justify-between mb-6">
	<h2 class="text-2xl font-extrabold font-headline">Create Memory</h2>
	<button
		onclick={handleSubmit}
		disabled={loading || !caption.trim()}
		class="px-5 py-2 bg-primary text-on-primary rounded-full text-sm font-label font-bold shadow-lg shadow-primary/20 disabled:opacity-40 hover:scale-105 active:scale-95 transition-all"
	>
		{loading ? 'Posting…' : 'Share'}
	</button>
</div>

<form onsubmit={handleSubmit} class="space-y-5 pb-28">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<!-- Image upload zone -->
	<div class="relative aspect-video rounded-2xl border-2 border-dashed border-outline-variant/40 bg-surface-container-low flex flex-col items-center justify-center gap-3 text-on-surface-variant overflow-hidden group cursor-pointer">
		<div class="absolute inset-0 bg-gradient-to-br from-primary/5 to-primary-container/5 opacity-0 group-hover:opacity-100 transition-opacity"></div>
		<span class="material-symbols-outlined text-4xl opacity-50">add_photo_alternate</span>
		<div class="text-center relative z-10">
			<p class="text-sm font-semibold">Upload session photo</p>
			<p class="text-xs opacity-60 mt-0.5">Image upload coming soon</p>
		</div>
	</div>

	<!-- Story / Caption -->
	<div>
		<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			The Story
		</label>
		<textarea
			rows="4"
			placeholder="What happened at the table?"
			bind:value={caption}
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
		></textarea>
	</div>

	<!-- Tag rows -->
	<div class="grid grid-cols-2 gap-3">
		<!-- Tag game -->
		<button
			type="button"
			class="flex items-center gap-3 bg-surface-container-low rounded-xl px-4 py-3 text-left hover:bg-surface-container transition-colors"
		>
			<span class="material-symbols-outlined text-primary text-[20px]">casino</span>
			<span class="text-sm font-semibold text-on-surface-variant">Tag Game</span>
			<span class="material-symbols-outlined text-on-surface-variant text-[16px] ml-auto">chevron_right</span>
		</button>

		<!-- Tag friends -->
		<button
			type="button"
			class="flex items-center gap-3 bg-surface-container-low rounded-xl px-4 py-3 text-left hover:bg-surface-container transition-colors"
		>
			<span class="material-symbols-outlined text-primary text-[20px]">group</span>
			<span class="text-sm font-semibold text-on-surface-variant">Tag Friends</span>
			<span class="material-symbols-outlined text-on-surface-variant text-[16px] ml-auto">chevron_right</span>
		</button>
	</div>

	<!-- Privacy -->
	<div class="flex items-center justify-between bg-surface-container-low rounded-xl px-4 py-3">
		<div class="flex items-center gap-3">
			<span class="material-symbols-outlined text-primary text-[20px]">public</span>
			<span class="text-sm font-semibold">Visibility</span>
		</div>
		<span class="text-sm font-label font-bold text-on-secondary-container bg-secondary-container px-3 py-1 rounded-full">
			Public
		</span>
	</div>

	<!-- Quick tags -->
	<div>
		<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mb-3">
			Quick Tags
		</label>
		<div class="flex flex-wrap gap-2">
			{#each quickTags as tag}
				<button
					type="button"
					onclick={() => toggleTag(tag)}
					class="px-3 py-1.5 rounded-full text-sm font-label font-bold transition-colors
						{selectedTags.includes(tag)
							? 'bg-primary text-on-primary'
							: 'bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest'}"
				>
					{tag}
				</button>
			{/each}
		</div>
	</div>
</form>
