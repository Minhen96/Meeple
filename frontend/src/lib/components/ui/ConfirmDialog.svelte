<script lang="ts">
	// Confirmation as a bottom sheet (SCREENS_AND_STATES section 14.2): icon + heading,
	// consequence text, confirm (red when destructive) and a ghost cancel.
	import BottomSheet from './BottomSheet.svelte';
	import Button from './Button.svelte';
	import { m } from '$lib/i18n';

	interface Props {
		title: string;
		message: string;
		confirmLabel?: string;
		cancelLabel?: string;
		danger?: boolean;
		/** Material Symbol shown next to the heading. */
		icon?: string;
		loading?: boolean;
		onConfirm: () => void;
		onCancel: () => void;
		children?: import('svelte').Snippet;
	}

	let {
		title,
		message,
		confirmLabel,
		cancelLabel,
		danger = false,
		icon,
		loading = false,
		onConfirm,
		onCancel,
		children
	}: Props = $props();
</script>

<BottomSheet label={title} onClose={onCancel}>
	<div class="flex items-center gap-3 mb-2">
		<span
			class="material-symbols-outlined text-[28px] {danger ? 'text-error' : 'text-primary'}"
			aria-hidden="true">{icon ?? (danger ? 'warning' : 'help')}</span
		>
		<h3 class="text-lg font-headline font-extrabold text-on-surface">{title}</h3>
	</div>
	<p class="text-sm text-on-surface-variant leading-relaxed mb-6">{message}</p>
	{@render children?.()}
	<div class="flex flex-col gap-2">
		<Button fullWidth variant={danger ? 'danger' : 'primary'} {loading} onclick={onConfirm}>
			{confirmLabel ?? m('common.confirm')}
		</Button>
		<button
			type="button"
			onclick={onCancel}
			class="w-full py-3 text-sm font-label font-bold text-on-surface-variant hover:text-on-surface transition-colors"
		>
			{cancelLabel ?? m('common.cancel')}
		</button>
	</div>
</BottomSheet>
