<!--
	Friend multi-select for invites (SCREENS section 6.5 item 6): selected friends as avatar chips
	above a searchable checkbox list. Only friends are listed: the backend rejects anyone else.
-->
<script lang="ts">
	import { onMount } from 'svelte';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { friendsApi } from '$lib/api/friends';
	import { m } from '$lib/i18n';
	import type { User } from '$lib/types';
	import { displayName, eventErrorMessage } from './eventState';
	import { filterFriends } from './friendFilter';

	interface Props {
		/** Selected user ids (bindable). */
		selected: string[];
		/** Users who cannot be picked (already invited or going). */
		excludeIds?: string[];
		/** Called once friends are loaded (e.g. to drop pre-selected ids that are not friends). */
		onLoaded?: (friends: User[]) => void;
	}

	let { selected = $bindable([]), excludeIds = [], onLoaded }: Props = $props();

	let friends = $state<User[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let query = $state('');

	const FRIEND_PAGE_SIZE = 100;

	onMount(async () => {
		try {
			const page = await friendsApi.getFriends(0, FRIEND_PAGE_SIZE);
			friends = page.data;
			onLoaded?.(page.data);
		} catch (err) {
			error = eventErrorMessage(err);
		} finally {
			loading = false;
		}
	});

	const pickable = $derived(friends.filter((f) => !excludeIds.includes(f.id)));
	const visible = $derived(filterFriends(pickable, query));
	const chosen = $derived(friends.filter((f) => selected.includes(f.id)));

	function toggle(id: string) {
		selected = selected.includes(id) ? selected.filter((s) => s !== id) : [...selected, id];
	}
</script>

<div class="space-y-3">
	{#if chosen.length > 0}
		<div class="flex flex-wrap gap-2" aria-live="polite">
			{#each chosen as friend (friend.id)}
				<button
					type="button"
					onclick={() => toggle(friend.id)}
					class="flex items-center gap-1.5 pl-1 pr-2 py-1 rounded-full bg-primary/10 text-primary text-xs font-label font-bold spring-bounce"
					aria-label={m('event.form.removeInvitee', { name: displayName(friend) })}
				>
					<Avatar src={friend.avatarUrl} name={displayName(friend)} size="xs" />
					<span class="max-w-[8rem] truncate">{displayName(friend)}</span>
					<span class="material-symbols-outlined text-[14px]" aria-hidden="true">close</span>
				</button>
			{/each}
		</div>
		<p class="text-[11px] font-label text-on-surface-variant">{m('event.form.selectedCount', { count: chosen.length })}</p>
	{/if}

	{#if loading}
		<div class="space-y-2" aria-hidden="true">
			{#each [0, 1, 2] as i (i)}
				<div class="h-12 rounded-lg bg-surface-container-high animate-pulse"></div>
			{/each}
		</div>
	{:else if error}
		<p class="text-sm text-error" role="alert">{error}</p>
	{:else if friends.length === 0}
		<p class="text-sm text-on-surface-variant">{m('event.form.noFriends')}</p>
	{:else}
		<div class="relative">
			<span
				class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-[18px]"
				aria-hidden="true">search</span
			>
			<input
				type="search"
				bind:value={query}
				placeholder={m('event.form.inviteSearch')}
				aria-label={m('event.form.inviteSearch')}
				class="w-full bg-surface-container-highest rounded-lg pl-10 pr-4 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/60 focus:outline-none focus:ring-2 focus:ring-primary/30"
			/>
		</div>
		<ul class="max-h-64 overflow-y-auto space-y-1">
			{#each visible as friend (friend.id)}
				{@const isSelected = selected.includes(friend.id)}
				<li>
					<label
						class="flex items-center gap-3 px-3 py-2 rounded-lg cursor-pointer transition-colors
							{isSelected ? 'bg-primary/10' : 'hover:bg-surface-container-high'}"
					>
						<input
							type="checkbox"
							checked={isSelected}
							onchange={() => toggle(friend.id)}
							class="w-4 h-4 accent-primary"
						/>
						<Avatar src={friend.avatarUrl} name={displayName(friend)} size="sm" />
						<span class="flex-1 min-w-0">
							<span class="block text-sm font-bold text-on-surface truncate">{displayName(friend)}</span>
							<span class="block text-[11px] text-on-surface-variant truncate">@{friend.username}</span>
						</span>
					</label>
				</li>
			{:else}
				<li class="text-sm text-on-surface-variant px-3 py-2">{m('event.form.noFriendMatches')}</li>
			{/each}
		</ul>
	{/if}
</div>
