<script lang="ts">
	// The bottom-nav "+" sheet (PLAN section 3.8): Post / Event / Add Game / Find Match.
	import { goto } from '$app/navigation';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import { m, type MessageKey } from '$lib/i18n';

	interface Props {
		onClose: () => void;
	}

	let { onClose }: Props = $props();

	const actions: { icon: string; label: MessageKey; hint: MessageKey; href: string }[] = [
		{ icon: 'add_photo_alternate', label: 'common.create.post', hint: 'common.create.postHint', href: '/posts/create' },
		{ icon: 'event', label: 'common.create.event', hint: 'common.create.eventHint', href: '/events/create' },
		{ icon: 'library_add', label: 'common.create.game', hint: 'common.create.gameHint', href: '/library' },
		{ icon: 'group_add', label: 'common.create.match', hint: 'common.create.matchHint', href: '/match' }
	];

	function open(href: string) {
		onClose();
		void goto(href);
	}
</script>

<BottomSheet title={m('common.create.title')} onClose={onClose}>
	<ul class="grid grid-cols-2 gap-3">
		{#each actions as action (action.href)}
			<li>
				<button
					type="button"
					onclick={() => open(action.href)}
					class="w-full h-full text-left rounded-2xl bg-surface-container-low hover:bg-surface-container p-4 flex flex-col gap-2 transition-colors active:scale-[0.98]"
				>
					<span
						class="w-10 h-10 rounded-full bg-secondary-container text-on-secondary-container flex items-center justify-center"
					>
						<span class="material-symbols-outlined text-[22px]" aria-hidden="true">{action.icon}</span>
					</span>
					<span class="font-headline font-bold text-on-surface">{m(action.label)}</span>
					<span class="text-xs text-on-surface-variant leading-snug">{m(action.hint)}</span>
				</button>
			</li>
		{/each}
	</ul>
</BottomSheet>
