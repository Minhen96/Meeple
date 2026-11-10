<script lang="ts">
	// Home right rail (desktop, xl+): pending friend requests to answer, then people you may know.
	// Loads its own data on mount; either list failing just hides that block.
	import { onMount } from 'svelte';
	import { friendsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m } from '$lib/i18n';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import Skeleton from '$lib/components/ui/Skeleton.svelte';
	import FriendButton from './FriendButton.svelte';
	import type { FriendRequest, FriendshipStatus, SuggestedUser } from '$lib/types';
	import { toast } from 'svelte-sonner';

	interface Props {
		/** How many requests and suggestions to show. */
		limit?: number;
	}

	let { limit = 4 }: Props = $props();

	let loading = $state(true);
	let requests = $state<FriendRequest[]>([]);
	let requestTotal = $state(0);
	let suggestions = $state<SuggestedUser[]>([]);
	let suggestionStatus = $state<Record<string, FriendshipStatus>>({});
	let busy = $state<string | null>(null);

	onMount(() => {
		void load();
	});

	async function load() {
		const [received, suggested] = await Promise.all([
			friendsApi.getReceived(0, limit).catch(() => null),
			friendsApi.suggestFriends(limit).catch((): SuggestedUser[] => [])
		]);
		requests = received?.data ?? [];
		requestTotal = received?.meta.total ?? 0;
		suggestions = suggested;
		loading = false;
	}

	async function respond(request: FriendRequest, accept: boolean) {
		if (busy) return;
		busy = request.id;
		try {
			await (accept ? friendsApi.accept(request.id) : friendsApi.decline(request.id));
			toast.success(m(accept ? 'social.friend.accepted' : 'social.friend.declined'));
			requests = requests.filter((r) => r.id !== request.id);
			requestTotal = Math.max(0, requestTotal - 1);
		} catch (err) {
			toast.error(
				err instanceof ApiRequestError ? errorMessage(err.code) : m('social.friend.failed')
			);
		} finally {
			busy = null;
		}
	}

	const nameOf = (u: { displayName: string | null; username: string }) =>
		u.displayName ?? u.username;
</script>

{#snippet heading(title: string, href: string)}
	<div class="mb-3 flex items-center justify-between">
		<h3 class="font-headline text-lg font-bold text-on-surface">{title}</h3>
		<a
			{href}
			class="rounded-full font-label text-xs font-bold uppercase tracking-widest text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
		>
			{m('social.home.seeAll')}
		</a>
	</div>
{/snippet}

{#if loading}
	<div class="space-y-3" aria-hidden="true">
		<Skeleton class="h-4 w-32" />
		{#each [0, 1, 2] as i (i)}
			<div class="flex items-center gap-3">
				<Skeleton rounded class="h-10 w-10" />
				<div class="flex-1 space-y-2"><Skeleton class="h-3 w-24" /><Skeleton class="h-2.5 w-16" /></div>
			</div>
		{/each}
	</div>
{:else}
	{#if requests.length > 0}
		<section data-testid="rail-requests">
			{@render heading(
				requestTotal > requests.length
					? `${m('social.home.requestsTitle')} (${requestTotal})`
					: m('social.home.requestsTitle'),
				'/people?tab=requests'
			)}
			<ul class="space-y-1 rounded-[1.5rem] bg-surface-container-low p-2">
				{#each requests as request (request.id)}
					<li class="flex items-center gap-3 rounded-2xl p-2 transition-colors hover:bg-surface-container">
						<a href="/profile/{request.sender.id}" class="flex min-w-0 flex-1 items-center gap-3 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
							<Avatar src={request.sender.avatarUrl} name={nameOf(request.sender)} size="md" />
							<span class="min-w-0">
								<span class="block truncate text-sm font-bold text-on-surface">{nameOf(request.sender)}</span>
								<span class="block truncate text-xs text-on-surface-variant">@{request.sender.username}</span>
							</span>
						</a>
						<button
							type="button"
							disabled={busy === request.id}
							onclick={() => respond(request, true)}
							aria-label={`${m('social.friend.accept')} · ${nameOf(request.sender)}`}
							title={m('social.friend.accept')}
							class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-primary to-primary-container text-on-primary transition-transform hover:scale-105 active:scale-95 disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
						>
							<span class="material-symbols-outlined text-[18px]" aria-hidden="true">check</span>
						</button>
						<button
							type="button"
							disabled={busy === request.id}
							onclick={() => respond(request, false)}
							aria-label={`${m('social.friend.decline')} · ${nameOf(request.sender)}`}
							title={m('social.friend.decline')}
							class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant transition-colors hover:bg-surface-container-highest hover:text-on-surface active:scale-95 disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
						>
							<span class="material-symbols-outlined text-[18px]" aria-hidden="true">close</span>
						</button>
					</li>
				{/each}
			</ul>
		</section>
	{/if}

	{#if suggestions.length > 0}
		<section class={requests.length > 0 ? 'mt-8' : ''} data-testid="rail-suggestions">
			{@render heading(m('social.home.suggestionsTitle'), '/people')}
			<ul class="space-y-1 rounded-[1.5rem] bg-surface-container-low p-2">
				{#each suggestions as user (user.id)}
					<li class="flex items-center gap-3 rounded-2xl p-2 transition-colors hover:bg-surface-container">
						<a href="/profile/{user.id}" class="flex min-w-0 flex-1 items-center gap-3 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
							<Avatar src={user.avatarUrl} name={nameOf(user)} size="md" />
							<span class="min-w-0">
								<span class="block truncate text-sm font-bold text-on-surface">{nameOf(user)}</span>
								<span class="block truncate text-xs text-on-surface-variant">
									{user.sharedGames === 0
										? m('social.people.newMember')
										: user.sharedGames === 1
											? m('social.people.sharedGamesOne')
											: m('social.people.sharedGames', { count: user.sharedGames })}
								</span>
							</span>
						</a>
						<FriendButton
							userId={user.id}
							status={suggestionStatus[user.id] ?? 'none'}
							onChange={(s) => (suggestionStatus = { ...suggestionStatus, [user.id]: s })}
						/>
					</li>
				{/each}
			</ul>
		</section>
	{/if}
{/if}
