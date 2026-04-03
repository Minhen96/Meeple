<script lang="ts">
	import { fade, scale } from 'svelte/transition';
	import Button from './Button.svelte';

	interface Props {
		title: string;
		message: string;
		confirmLabel?: string;
		cancelLabel?: string;
		danger?: boolean;
		onConfirm: () => void;
		onCancel: () => void;
	}

	let {
		title,
		message,
		confirmLabel = 'Confirm',
		cancelLabel = 'Cancel',
		danger = false,
		onConfirm,
		onCancel
	}: Props = $props();
</script>

<div
	class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
	transition:fade={{ duration: 200 }}
>
	<div
		class="bg-surface rounded-2xl w-full max-w-xs shadow-2xl p-6"
		transition:scale={{ duration: 300, start: 0.95, opacity: 0 }}
	>
		<h3 class="text-lg font-headline font-extrabold text-on-surface mb-2">{title}</h3>
		<p class="text-sm text-on-surface-variant leading-relaxed mb-6">{message}</p>

		<div class="flex flex-col gap-2">
			<Button
				fullWidth
				variant={danger ? 'danger' : 'primary'}
				onclick={onConfirm}
			>
				{confirmLabel}
			</Button>
			<button
				onclick={onCancel}
				class="w-full py-2.5 text-sm font-label font-bold text-on-surface-variant hover:text-on-surface transition-colors"
			>
				{cancelLabel}
			</button>
		</div>
	</div>
</div>
