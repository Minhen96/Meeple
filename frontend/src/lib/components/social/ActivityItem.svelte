<script lang="ts">
	import type { Activity } from '$lib/types';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { m, type MessageKey } from '$lib/i18n';
	import { displayName, splitTemplate, timeAgo } from './format';

	/** Compact system item in the feed (SCREENS_AND_STATES 7.3): "[User] added [Game] to their collection." */
	interface Props {
		activity: Activity;
		createdAt: string;
	}
	let { activity, createdAt }: Props = $props();

	const TEMPLATES: Record<Activity['type'], { key: MessageKey; slot: 'game' | 'event' }> = {
		collection_add: { key: 'social.activity.collectionAdd', slot: 'game' },
		event_created: { key: 'social.activity.eventCreated', slot: 'event' },
		event_joined: { key: 'social.activity.eventJoined', slot: 'event' }
	};

	const name = $derived(displayName(activity.user));
	const template = $derived(TEMPLATES[activity.type]);
	const parts = $derived(splitTemplate(m(template.key, { name }), template.slot));
	const subject = $derived(
		template.slot === 'game'
			? {
					label: activity.data.gameName ?? '',
					href: activity.data.gameId ? `/library/${activity.data.gameId}` : null
				}
			: {
					label: activity.data.eventTitle ?? '',
					href: activity.data.eventId ? `/events/${activity.data.eventId}` : null
				}
	);
	const source = $derived(
		m(template.slot === 'game' ? 'social.activity.fromLibrary' : 'social.activity.fromEvents')
	);
</script>

<div class="flex items-start gap-3 rounded-2xl bg-surface-container-low px-4 py-3">
	{#if activity.user.deleted}
		<Avatar {name} size="md" />
	{:else}
		<a href="/profile/{activity.user.id}" aria-label={name}>
			<Avatar src={activity.user.avatarUrl} {name} size="md" />
		</a>
	{/if}
	<div class="min-w-0 flex-1">
		<p class="text-sm leading-snug text-on-surface">
			{parts[0]}{#if subject.href}<a
					href={subject.href}
					class="font-semibold italic text-primary hover:underline">{subject.label}</a
				>{:else}<span class="font-semibold italic text-primary">{subject.label}</span
				>{/if}{parts[1]}
		</p>
		<p class="mt-0.5 font-label text-[10px] text-on-surface-variant">
			{timeAgo(createdAt)} · {source}
		</p>
	</div>
	{#if activity.data.gameThumbnailUrl}
		<img
			src={activity.data.gameThumbnailUrl}
			alt=""
			class="h-10 w-10 flex-shrink-0 rounded-lg object-cover"
			loading="lazy"
		/>
	{/if}
</div>
