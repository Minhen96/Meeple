<script lang="ts">
	import { postsApi } from '$lib/api/posts';
	import { uploadApi } from '$lib/api/upload';
	import { gamesApi } from '$lib/api/games';
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { fade, fly, scale } from 'svelte/transition';
	import Button from '$lib/components/ui/Button.svelte';
	import Avatar from '$lib/components/ui/Avatar.svelte';

	let caption = $state('');
	let loading = $state(false);
	let error = $state('');

	// Image state
	let images = $state<File[]>([]);
	let previews = $state<string[]>([]);
	let fileInput: HTMLInputElement;

	// Tagging state
	let taggedGame = $state<any>(null);
	let taggedFriends = $state<any[]>([]);
	let showGameSearch = $state(false);
	let showFriendSearch = $state(false);
	let gameQuery = $state('');
	let gameResults = $state<any[]>([]);
	let friendsList = $state<any[]>([]);

	// Quick tag chips
	const quickTags = ['#GameNight', '#VictoryRoyale', '#TableTopLife', '#BoardGames', '#NewToMe'];
	let selectedTags = $state<string[]>([]);

	function toggleTag(tag: string) {
		selectedTags = selectedTags.includes(tag)
			? selectedTags.filter((t) => t !== tag)
			: [...selectedTags, tag];
	}

	function handleFileSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		if (target.files) {
			const newFiles = Array.from(target.files);
			if (images.length + newFiles.length > 10) {
				toast.error('Maximum 10 images allowed');
				return;
			}
			images = [...images, ...newFiles];
			const newPreviews = newFiles.map((f) => URL.createObjectURL(f));
			previews = [...previews, ...newPreviews];
		}
	}

	function removeImage(index: number) {
		URL.revokeObjectURL(previews[index]);
		images = images.filter((_, i) => i !== index);
		previews = previews.filter((_, i) => i !== index);
	}

	async function searchGames() {
		if (gameQuery.length < 2) return;
		try {
			gameResults = await gamesApi.search(gameQuery);
		} catch (err) {
			console.error(err);
		}
	}

	async function loadFriends() {
		try {
			const res = await friendsApi.getFriends();
			friendsList = res.data;
		} catch (err) {
			console.error(err);
		}
	}

	function toggleFriend(friend: any) {
		const exists = taggedFriends.find(f => f.id === friend.id);
		if (exists) {
			taggedFriends = taggedFriends.filter(f => f.id !== friend.id);
		} else {
			taggedFriends = [...taggedFriends, friend];
		}
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (images.length === 0) {
			error = 'At least one image is required.';
			return;
		}
		
		error = '';
		loading = true;

		try {
			// 1. Upload images
			const imageKeys: string[] = [];
			for (const file of images) {
				const { key } = await uploadApi.direct(file);
				imageKeys.push(key);
			}

			// 2. Format caption
			const fullCaption = selectedTags.length
				? `${caption.trim()} ${selectedTags.join(' ')}`
				: caption.trim();

			// 3. Create post
			await postsApi.createPost({ 
				caption: fullCaption,
				imageKeys,
				gameId: taggedGame?.id,
				taggedUserIds: taggedFriends.map(f => f.id)
			});

			toast.success('Posted!');
			goto('/');
		} catch (err) {
			error = err instanceof ApiRequestError ? err.message : 'Something went wrong during upload or posting.';
			console.error(err);
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		if (showFriendSearch && friendsList.length === 0) {
			loadFriends();
		}
	});
</script>

<svelte:head><title>Create Post — Meeple</title></svelte:head>

<div class="relative min-h-screen overflow-x-hidden pb-24">
	<!-- Decorative Background -->
	<div class="absolute -top-32 -left-32 w-80 h-80 bg-tertiary/10 rounded-full blur-3xl -z-10"></div>
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
		</div>
	</div>

	<form onsubmit={handleSubmit} class="px-4 space-y-6 max-w-2xl mx-auto">
		{#if error}
			<div class="text-xs font-semibold text-error bg-error-container/30 border border-error/20 rounded-2xl px-4 py-3 animate-in fade-in slide-in-from-top-2">
				{error}
			</div>
		{/if}

		<!-- Image Upload Area -->
		<div class="space-y-3">
			<div class="flex items-center justify-between px-1">
				<h3 class="text-[10px] font-label font-black uppercase tracking-widest text-on-surface-variant/70">Images ({images.length}/10)</h3>
				{#if images.length > 0}
					<button type="button" onclick={() => fileInput.click()} class="text-[10px] font-bold text-primary uppercase">Add More</button>
				{/if}
			</div>

			{#if previews.length === 0}
				<button 
					type="button"
					onclick={() => fileInput.click()}
					class="w-full aspect-square rounded-[2.5rem] border-2 border-dashed border-outline-variant/30 bg-surface-container-low/50 flex flex-col items-center justify-center gap-4 text-on-surface-variant hover:border-tertiary/40 transition-all active:scale-[0.99]"
				>
					<div class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center shadow-inner">
						<span class="material-symbols-outlined text-3xl text-tertiary">add_photo_alternate</span>
					</div>
					<div class="text-center">
						<p class="text-sm font-black font-headline">Capture the Moment</p>
						<p class="text-[10px] opacity-50 uppercase tracking-tighter">Support up to 10 photos</p>
					</div>
				</button>
			{:else}
				<div class="flex gap-3 overflow-x-auto hide-scrollbar pb-2">
					{#each previews as url, i}
						<div class="relative flex-shrink-0 w-32 aspect-square rounded-2xl overflow-hidden shadow-sm group">
							<img src={url} alt="Preview" class="w-full h-full object-cover" />
							<button 
								type="button" 
								onclick={() => removeImage(i)}
								class="absolute top-1.5 right-1.5 w-6 h-6 rounded-full bg-black/60 text-white flex items-center justify-center backdrop-blur-sm opacity-0 group-hover:opacity-100 transition-opacity"
							>
								<span class="material-symbols-outlined text-xs">close</span>
							</button>
						</div>
					{/each}
					{#if images.length < 10}
						<button 
							type="button"
							onclick={() => fileInput.click()}
							class="flex-shrink-0 w-32 aspect-square rounded-2xl border-2 border-dashed border-outline-variant/30 bg-surface-container-low/50 flex flex-col items-center justify-center text-on-surface-variant"
						>
							<span class="material-symbols-outlined text-xl">add</span>
						</button>
					{/if}
				</div>
			{/if}
			<input type="file" multiple accept="image/*" bind:this={fileInput} onchange={handleFileSelect} class="hidden" />
		</div>

		<!-- Story Card -->
		<div class="bg-surface-container-low rounded-[2rem] p-6 shadow-sm border border-outline-variant/20 space-y-4">
			<textarea
				rows="4"
				placeholder="Share the story behind this session…"
				bind:value={caption}
				class="w-full bg-transparent border-none text-base font-body text-on-surface placeholder:text-on-surface-variant/30 focus:ring-0 focus:outline-none resize-none px-1"
			></textarea>
			
			<div class="flex flex-wrap gap-2 pt-2 border-t border-outline-variant/10">
				{#each quickTags as tag}
					<button
						type="button"
						onclick={() => toggleTag(tag)}
						class="px-3 py-1.5 rounded-full text-xs font-bold transition-all
							{selectedTags.includes(tag) ? 'bg-tertiary text-on-tertiary' : 'bg-surface-container-high text-on-surface-variant'}"
					>
						{tag}
					</button>
				{/each}
			</div>
		</div>

		<!-- Tagging -->
		<div class="grid grid-cols-1 gap-3">
			<!-- Game Tag -->
			<div
				role="button"
				tabindex="0"
				onclick={() => { showGameSearch = true; }}
				onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') showGameSearch = true; }}
				class="flex items-center gap-4 bg-surface-container-low/60 rounded-2xl p-4 border border-outline-variant/10 text-left hover:border-primary/30 transition-all active:scale-[0.98] cursor-pointer"
			>
				<div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
					<span class="material-symbols-outlined text-[20px]">casino</span>
				</div>
				<div class="flex-1">
					<p class="text-sm font-bold">{taggedGame ? taggedGame.title : 'Tag Game'}</p>
					<p class="text-[10px] text-on-surface-variant/60 uppercase tracking-tighter">Which board game?</p>
				</div>
				{#if taggedGame}
					<button 
						type="button" 
						onclick={(e) => { e.stopPropagation(); taggedGame = null; }} 
						class="text-on-surface-variant/40 hover:text-on-surface transition-colors"
						aria-label="Remove tagged game"
					>
						<span class="material-symbols-outlined text-sm">close</span>
					</button>
				{:else}
					<span class="material-symbols-outlined text-on-surface-variant/40 text-[18px]">add</span>
				{/if}
			</div>

			<!-- Friend Tags -->
			<button
				type="button"
				onclick={() => showFriendSearch = true}
				class="flex items-center gap-4 bg-surface-container-low/60 rounded-2xl p-4 border border-outline-variant/10 text-left hover:border-secondary/30 transition-all active:scale-[0.98]"
			>
				<div class="w-10 h-10 rounded-xl bg-secondary/10 flex items-center justify-center text-secondary">
					<span class="material-symbols-outlined text-[20px]">group</span>
				</div>
				<div class="flex-1">
					<p class="text-sm font-bold">
						{#if taggedFriends.length === 0}Tag Friends{:else}{taggedFriends.length} Friends Tagged{/if}
					</p>
					<p class="text-[10px] text-on-surface-variant/60 uppercase tracking-tighter">Who played with you?</p>
				</div>
				<span class="material-symbols-outlined text-on-surface-variant/40 text-[18px]">add</span>
			</button>
		</div>

		<!-- Form Actions -->
		<div class="pt-4">
			<button
				type="submit"
				disabled={loading || images.length === 0}
				class="w-full h-16 bg-on-surface text-surface rounded-3xl font-headline font-black text-lg shadow-xl active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-3 overflow-hidden"
			>
				{#if loading}
					<div class="w-5 h-5 border-2 border-surface/30 border-t-surface rounded-full animate-spin"></div>
					<span>Uploading & Posting…</span>
				{:else}
					<span class="material-symbols-outlined text-[20px]">send</span>
					<span>Share Post</span>
				{/if}
			</button>
		</div>
	</form>
</div>

<!-- Game Search Modal -->
{#if showGameSearch}
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4" transition:fade>
		<button class="absolute inset-0 bg-black/60 backdrop-blur-sm" onclick={() => showGameSearch = false} aria-label="Close modal"></button>
		<div class="relative w-full max-w-lg bg-surface rounded-[2.5rem] shadow-2xl p-6 flex flex-col gap-6" transition:fly={{ y: 20 }}>
			<div class="flex items-center justify-between">
				<h3 class="text-xl font-black font-headline">Tag a Game</h3>
				<button onclick={() => showGameSearch = false} class="w-8 h-8 rounded-full bg-surface-container flex items-center justify-center" aria-label="Close modal">
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>
			
			<div class="relative">
				<span class="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant/50">search</span>
				<input 
					type="text" 
					placeholder="Search your library or BGG..."
					bind:value={gameQuery}
					oninput={searchGames}
					class="w-full h-12 bg-surface-container rounded-2xl pl-12 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
				/>
			</div>

			<div class="max-h-64 overflow-y-auto space-y-2 pr-1 pb-10">
				{#each gameResults as game}
					<button 
						onclick={() => { taggedGame = game; showGameSearch = false; }}
						class="w-full flex items-center gap-3 p-2 rounded-xl hover:bg-surface-container transition-colors"
					>
						<img src={game.thumbnailUrl} alt="" class="w-10 h-10 rounded-lg object-cover bg-surface-container" />
						<div class="text-left">
							<p class="text-sm font-bold leading-tight">{game.title}</p>
							<p class="text-[10px] text-on-surface-variant">{game.yearPublished || 'Unstyled'}</p>
						</div>
					</button>
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Friend Search Modal -->
{#if showFriendSearch}
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4" transition:fade>
		<button class="absolute inset-0 bg-black/60 backdrop-blur-sm" onclick={() => showFriendSearch = false} aria-label="Close modal"></button>
		<div class="relative w-full max-w-lg bg-surface rounded-[2.5rem] shadow-2xl p-6 flex flex-col gap-6" transition:fly={{ y: 20 }}>
			<div class="flex items-center justify-between">
				<h3 class="text-xl font-black font-headline">Tag Friends</h3>
				<button onclick={() => showFriendSearch = false} class="w-8 h-8 rounded-full bg-surface-container flex items-center justify-center" aria-label="Close modal">
					<span class="material-symbols-outlined text-sm">close</span>
				</button>
			</div>

			<div class="max-h-80 overflow-y-auto space-y-2 pr-1 pb-10">
				{#if friendsList.length === 0}
					<p class="text-center py-12 text-sm text-on-surface-variant opacity-50">No friends found</p>
				{:else}
					{#each friendsList as friend}
						<button 
							onclick={() => toggleFriend(friend)}
							class="w-full flex items-center justify-between p-3 rounded-2xl transition-colors
								{taggedFriends.find(f => f.id === friend.id) ? 'bg-secondary/10' : 'hover:bg-surface-container'}"
						>
							<div class="flex items-center gap-3">
								<Avatar src={friend.avatarUrl} name={friend.displayName ?? friend.username} size="sm" />
								<p class="text-sm font-bold">{friend.displayName ?? friend.username}</p>
							</div>
							{#if taggedFriends.find(f => f.id === friend.id)}
								<span class="material-symbols-outlined text-secondary">check_circle</span>
							{:else}
								<span class="material-symbols-outlined text-on-surface-variant/30">add_circle</span>
							{/if}
						</button>
					{/each}
				{/if}
			</div>

			<Button fullWidth onclick={() => showFriendSearch = false}>Done</Button>
		</div>
	</div>
{/if}

