<script lang="ts">
	import { postsApi } from '$lib/api/posts';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { fade, fly, scale } from 'svelte/transition';

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
			await postsApi.createPost({ caption: fullCaption });
			toast.success('Posted!');
			goto('/');
		} catch (err) {
			error = err instanceof ApiRequestError ? err.message : 'Something went wrong.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Post — Meeple</title></svelte:head>

<div class="relative min-h-screen overflow-x-hidden pb-20">
	<!-- Decorative Background -->
	<div class="absolute -top-32 -left-32 w-80 h-80 bg-tertiary/10 rounded-full blur-3xl -z-10 animate-pulse"></div>
	<div class="absolute bottom-1/4 -right-32 w-96 h-96 bg-primary/5 rounded-full blur-3xl -z-10"></div>

	<!-- Header -->
	<div class="flex items-center gap-3 mb-6 mt-4 px-4 sticky top-4 z-20">
		<button
			onclick={() => history.back()}
			class="w-11 h-11 rounded-2xl bg-surface-container-low/80 backdrop-blur-md border border-outline-variant/30 flex items-center justify-center text-on-surface hover:bg-surface-container-high transition-all active:scale-90 shadow-sm"
			aria-label="Back"
		>
			<span class="material-symbols-outlined text-[24px]">arrow_back</span>
		</button>
		<div class="flex-1 text-center pr-11">
			<h2 class="text-2xl font-black font-headline tracking-tight text-on-surface">New Post</h2>
			<p class="text-[11px] font-label font-bold text-on-surface-variant/60 uppercase tracking-widest">Share a moment</p>
		</div>
	</div>

	<form onsubmit={handleSubmit} class="px-4 space-y-6 max-w-2xl mx-auto" in:fade={{ duration: 300 }}>
		{#if error}
			<div class="text-xs font-semibold text-error bg-error-container/30 border border-error/20 rounded-2xl px-4 py-3 animate-in fade-in slide-in-from-top-2">
				{error}
			</div>
		{/if}

		<!-- Image Upload Composer -->
		<div class="group relative aspect-[4/3] rounded-[2.5rem] border-2 border-dashed border-outline-variant/30 bg-surface-container-low/50 flex flex-col items-center justify-center gap-4 text-on-surface-variant overflow-hidden cursor-pointer transition-all hover:border-tertiary/40 hover:bg-tertiary/[0.02]">
			<div class="absolute inset-0 bg-gradient-to-br from-tertiary/5 to-primary/5 opacity-0 group-hover:opacity-100 transition-opacity"></div>
			
			<div class="w-20 h-20 rounded-3xl bg-surface-container-high flex items-center justify-center shadow-inner group-hover:scale-110 transition-transform duration-500">
				<span class="material-symbols-outlined text-4xl text-tertiary opacity-80">add_photo_alternate</span>
			</div>
			
			<div class="text-center relative z-10 space-y-1">
				<p class="text-base font-black font-headline text-on-surface/80">Add session photos</p>
				<div class="flex items-center justify-center gap-2">
					<span class="px-2 py-0.5 rounded-md bg-tertiary/10 text-[10px] font-black uppercase text-tertiary">Feature Lab</span>
					<p class="text-xs font-medium opacity-50">Upload coming soon</p>
				</div>
			</div>
			
			<!-- Bottom decorative bar -->
			<div class="absolute bottom-6 left-6 right-6 flex items-center gap-2 opacity-40">
				<div class="h-1 flex-1 bg-surface-container-highest rounded-full overflow-hidden">
					<div class="h-full w-1/3 bg-tertiary rounded-full"></div>
				</div>
				<span class="text-[10px] font-black uppercase tracking-tighter">Drafting Mode</span>
			</div>
		</div>

		<!-- Story Card -->
		<div class="bg-surface-container-low rounded-[2rem] p-6 shadow-sm border border-outline-variant/20 space-y-4">
			<div class="flex items-center gap-3 px-1">
				<div class="w-1 h-4 bg-tertiary rounded-full"></div>
				<label for="story" class="text-[10px] font-label font-black uppercase tracking-widest text-on-surface-variant/70">
					Your Story
				</label>
			</div>
			<textarea
				id="story"
				rows="5"
				placeholder="The dice were hot tonight! We finally finished the campaign..."
				bind:value={caption}
				class="w-full bg-transparent border-none text-lg font-body text-on-surface placeholder:text-on-surface-variant/30 focus:ring-0 focus:outline-none resize-none px-1"
			></textarea>
			
			<div class="flex flex-wrap gap-2 pt-2 border-t border-outline-variant/10">
				{#each quickTags as tag}
					<button
						type="button"
						onclick={() => toggleTag(tag)}
						class="px-4 py-2 rounded-xl text-xs font-black font-label transition-all
							{selectedTags.includes(tag)
								? 'bg-tertiary text-on-tertiary shadow-md shadow-tertiary/20 scale-105'
								: 'bg-surface-container-high text-on-surface-variant/70 hover:bg-surface-container-highest hover:text-on-surface'}"
					>
						{tag}
					</button>
				{/each}
			</div>
		</div>

		<!-- Metadata Grid -->
		<div class="grid grid-cols-1 gap-3">
			<!-- Tag game -->
			<button
				type="button"
				class="group flex items-center gap-4 bg-surface-container-low/60 rounded-2xl p-4 border border-outline-variant/10 text-left hover:bg-surface-container-low hover:border-primary/30 transition-all active:scale-[0.98]"
			>
				<div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary group-hover:scale-110 transition-transform">
					<span class="material-symbols-outlined text-[22px]">casino</span>
				</div>
				<div class="flex-1">
					<p class="text-sm font-black font-headline">Tag Game</p>
					<p class="text-[11px] text-on-surface-variant/60">Which game did you play?</p>
				</div>
				<span class="material-symbols-outlined text-on-surface-variant/40 text-[20px] group-hover:translate-x-1 transition-transform">arrow_forward</span>
			</button>

			<!-- Tag friends -->
			<button
				type="button"
				class="group flex items-center gap-4 bg-surface-container-low/60 rounded-2xl p-4 border border-outline-variant/10 text-left hover:bg-surface-container-low hover:border-secondary/30 transition-all active:scale-[0.98]"
			>
				<div class="w-10 h-10 rounded-xl bg-secondary/10 flex items-center justify-center text-secondary group-hover:scale-110 transition-transform">
					<span class="material-symbols-outlined text-[22px]">group</span>
				</div>
				<div class="flex-1">
					<p class="text-sm font-black font-headline">Tag Friends</p>
					<p class="text-[11px] text-on-surface-variant/60">Who else was there?</p>
				</div>
				<span class="material-symbols-outlined text-on-surface-variant/40 text-[20px] group-hover:translate-x-1 transition-transform">arrow_forward</span>
			</button>

			<!-- Privacy -->
			<div class="flex items-center justify-between bg-surface-container-low/60 rounded-2xl p-4 border border-outline-variant/10">
				<div class="flex items-center gap-4">
					<div class="w-10 h-10 rounded-xl bg-surface-container-highest flex items-center justify-center text-on-surface-variant">
						<span class="material-symbols-outlined text-[22px]">public</span>
					</div>
					<div>
						<p class="text-sm font-black font-headline">Visibility</p>
						<p class="text-[11px] text-on-surface-variant/60">Choose who sees this</p>
					</div>
				</div>
				<div class="px-4 py-1.5 rounded-full bg-secondary-container text-on-secondary-container text-[11px] font-black uppercase tracking-wider">
					Public
				</div>
			</div>
		</div>

		<!-- Bottom Action -->
		<div class="mt-8 pb-12">
			<button
				type="submit"
				disabled={loading || !caption.trim()}
				class="w-full h-16 bg-on-surface text-surface rounded-[1.25rem] font-headline font-black text-lg shadow-xl hover:scale-[1.01] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-3 overflow-hidden relative group"
			>
				<div class="absolute inset-0 bg-gradient-to-r from-tertiary to-primary opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
				<span class="material-symbols-outlined text-[20px] relative z-10 group-hover:animate-bounce">send</span>
				<span class="relative z-10">{loading ? 'Posting…' : 'Share Post'}</span>
			</button>
		</div>
	</form>
</div>

