<script lang="ts">
	import type { PageData } from './$types';
	import Avatar from '$lib/components/ui/Avatar.svelte';
    import { friendsApi } from '$lib/api/friends';
    import { toast } from 'svelte-sonner';

	interface Props { data: PageData }
	let { data }: Props = $props();

    let friends = $state<typeof data.friends>([]);

	$effect(() => {
		friends = data.friends;
	});

    async function handleUnfriend(userId: string) {
        if (!confirm('Are you sure you want to remove this friend?')) return;
        try {
            await friendsApi.unfriend(userId);
            friends = friends.filter(f => f.id !== userId);
            toast.success('Friend removed');
        } catch {
            toast.error('Could not remove friend');
        }
    }
</script>

<svelte:head><title>My Friends — Meeple</title></svelte:head>

<div class="pb-32 pt-6">
    <!-- Header/Back -->
    <div class="flex items-center gap-4 mb-8">
        <button
            onclick={() => history.back()}
            class="w-10 h-10 rounded-full bg-surface-container-high flex items-center justify-center text-on-surface-variant hover:text-primary transition-all active:scale-95"
        >
            <span class="material-symbols-outlined text-[20px]">arrow_back</span>
        </button>
        <h2 class="text-xl font-black font-headline tracking-tight text-on-surface">My Friends</h2>
    </div>

    {#if friends.length > 0}
        <div class="space-y-3">
            {#each friends as user (user.id)}
                <div class="flex items-center gap-4 p-4 bg-surface-container-low rounded-3xl border border-surface-variant/10 hover:bg-surface-container transition-colors shadow-sm">
                    <a href="/profile/{user.id}"><Avatar src={user.avatarUrl} size="md" /></a>
                    <div class="flex-1 min-w-0">
                        <a href="/profile/{user.id}" class="font-extrabold text-sm text-on-surface">
                            {user.displayName ?? user.username}
                        </a>
                        <p class="text-xs text-on-surface-variant">@{user.username}</p>
                    </div>
                    <button 
                        onclick={() => handleUnfriend(user.id)}
                        class="w-10 h-10 rounded-full bg-surface-container-highest flex items-center justify-center text-on-surface-variant hover:text-error transition-all active:scale-95"
                        aria-label="Remove friend"
                    >
                        <span class="material-symbols-outlined text-[20px]">person_remove</span>
                    </button>
                </div>
            {/each}
        </div>
    {:else}
        <div class="text-center py-20 opacity-30">
            <span class="material-symbols-outlined text-5xl mb-4">group_off</span>
            <p class="text-lg font-bold">No friends yet</p>
            <a href="/people" class="text-sm text-primary font-bold hover:underline mt-2 inline-block">Find people to follow</a>
        </div>
    {/if}
</div>
