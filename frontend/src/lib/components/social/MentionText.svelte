<script lang="ts">
	import { tokenizeMentions } from './mentions';

	/** Renders comment text with `@username` mentions highlighted (plain text, never HTML). */
	interface Props {
		text: string;
	}
	let { text }: Props = $props();

	const segments = $derived(tokenizeMentions(text));
</script>

{#each segments as segment, i (i)}{#if segment.type === 'mention'}<span
			class="font-semibold text-primary">{segment.value}</span
		>{:else}{segment.value}{/if}{/each}
