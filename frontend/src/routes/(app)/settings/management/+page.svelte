<script lang="ts">
	import { onMount } from 'svelte';
	import { friendsApi } from '$lib/api/friends';
	import { adminApi } from '$lib/api/admin';
	import { currentUser } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import type { User } from '$lib/types';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { fade, fly } from 'svelte/transition';

	let friends = $state<User[]>([]);
	let loading = $state(true);
	let promotingId = $state<string | null>(null);
	let searchQuery = $state('');

	const filteredFriends = $derived(
		friends.filter(f => 
			!f.isAdmin && 
			(f.username.toLowerCase().includes(searchQuery.toLowerCase()) || 
			 (f.displayName?.toLowerCase() || '').includes(searchQuery.toLowerCase()))
		)
	);

	onMount(async () => {
		if (!$currentUser?.isAdmin) {
			goto('/');
			return;
		}
		await loadFriends();
	});

	async function loadFriends() {
		loading = true;
		try {
			const res = await friendsApi.getFriends(0, 100);
			friends = res.data;
		} catch (e) {
			toast.error('Failed to load friends');
		} finally {
			loading = false;
		}
	}

	async function promote(user: User) {
		if (!confirm(`Are you sure you want to promote ${user.displayName || user.username} to Admin? This action cannot be undone.`)) {
			return;
		}

		promotingId = user.id;
		try {
			await adminApi.promoteUser(user.id);
			toast.success(`${user.displayName || user.username} is now an Admin`);
			// Remove from list or update local state
			friends = friends.filter(f => f.id !== user.id);
		} catch (e) {
			toast.error('Failed to promote user');
		} finally {
			promotingId = null;
		}
	}
</script>

<svelte:head><title>Manage Admins — Meeple</title></svelte:head>

<div class="py-4 space-y-6 pb-24">
	<!-- Header -->
	<div class="flex items-center gap-4">
		<button 
			onclick={() => history.back()}
			class="w-10 h-10 rounded-xl bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
			aria-label="Back"
		>
			<span class="material-symbols-outlined text-[20px]">arrow_back</span>
		</button>
		<div class="flex-1">
			<p class="text-[10px] font-bold uppercase tracking-widest text-primary mb-0.5">Management</p>
			<h1 class="text-xl font-black font-headline tracking-tight">Promote Admin</h1>
		</div>
	</div>

	<!-- Description -->
	<div class="bg-primary/5 border border-primary/10 rounded-2xl p-4 flex gap-3 items-start">
		<span class="material-symbols-outlined text-primary text-[20px]">info</span>
		<p class="text-xs text-on-surface-variant leading-relaxed">
			Select a trusted friend to grant them administrative privileges. They will be able to review rulebooks, manage system settings, and moderate content.
		</p>
	</div>

	<!-- Search -->
	<div class="relative">
		<span class="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant/50 text-[18px]">search</span>
		<input 
			type="text" 
			placeholder="Search friends..."
			bind:value={searchQuery}
			class="w-full h-11 bg-surface-container-lowest border border-outline-variant/10 rounded-xl pl-11 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-shadow"
		/>
	</div>

	<!-- Friends List -->
	<div class="space-y-2">
		{#if loading}
			{#each [1, 2, 3] as _}
				<div class="flex items-center justify-between p-3 bg-surface-container-lowest rounded-2xl animate-pulse">
					<div class="flex items-center gap-3">
						<div class="w-10 h-10 rounded-full bg-surface-container-high"></div>
						<div class="space-y-1.5">
							<div class="h-3 w-24 rounded-full bg-surface-container-high"></div>
							<div class="h-2 w-16 rounded-full bg-surface-container-high opacity-50"></div>
						</div>
					</div>
					<div class="w-20 h-8 rounded-lg bg-surface-container-high"></div>
				</div>
			{/each}
		{:else if filteredFriends.length === 0}
			<div class="text-center py-20 bg-surface-container-lowest rounded-3xl border border-outline-variant/10 border-dashed" in:fade>
				<span class="material-symbols-outlined text-4xl text-on-surface-variant/20 block mb-3">person_search</span>
				<p class="text-sm font-bold text-on-surface-variant">No friends found</p>
				<p class="text-[10px] text-on-surface-variant opacity-60 mt-1">Try a different search or add more friends.</p>
			</div>
		{:else}
			{#each filteredFriends as friend (friend.id)}
				<div 
					class="flex items-center justify-between p-3 bg-surface-container-lowest border border-outline-variant/10 rounded-2xl group hover:shadow-md transition-shadow"
					in:fly={{ y: 10 }}
				>
					<div class="flex items-center gap-3">
						<Avatar src={friend.avatarUrl} name={friend.displayName || friend.username} size="md" />
						<div>
							<p class="text-sm font-bold text-on-surface">{friend.displayName || friend.username}</p>
							<p class="text-[10px] text-on-surface-variant">@{friend.username}</p>
						</div>
					</div>
					
					<button 
						onclick={() => promote(friend)}
						disabled={promotingId === friend.id}
						class="h-9 px-4 rounded-lg bg-primary text-on-primary text-xs font-bold shadow-sm hover:shadow-md active:scale-95 disabled:opacity-50 transition-all flex items-center gap-2"
					>
						{#if promotingId === friend.id}
							<span class="material-symbols-outlined text-[16px] animate-spin">progress_activity</span>
						{:else}
							<span class="material-symbols-outlined text-[16px]">add_moderator</span>
						{/if}
						Promote
					</button>
				</div>
			{/each}
		{/if}
	</div>
</div>
