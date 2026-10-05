<script lang="ts">
	import { fade, fly } from 'svelte/transition';
	import { reportsApi } from '$lib/api/friends';
	import { ApiRequestError } from '$lib/api/client';
	import { errorMessage, m, type MessageKey } from '$lib/i18n';
	import type { ReportTargetType } from '$lib/types';
	import Button from '$lib/components/ui/Button.svelte';
	import { toast } from 'svelte-sonner';

	/** Bottom sheet for reporting a user, post or comment (FEATURES_COMPLETE 2.4). */
	interface Props {
		targetType: ReportTargetType;
		targetId: string;
		/** Sheet heading, e.g. m('social.report.titleUser', { name }). */
		title: string;
		onClose: () => void;
	}

	let { targetType, targetId, title, onClose }: Props = $props();

	const REASONS: { value: string; key: MessageKey }[] = [
		{ value: 'spam', key: 'social.report.reasonSpam' },
		{ value: 'harassment', key: 'social.report.reasonHarassment' },
		{ value: 'inappropriate', key: 'social.report.reasonInappropriate' },
		{ value: 'impersonation', key: 'social.report.reasonImpersonation' },
		{ value: 'other', key: 'social.report.reasonOther' }
	];

	let reason = $state('');
	let details = $state('');
	let sending = $state(false);

	async function submit(e: SubmitEvent) {
		e.preventDefault();
		if (!reason || sending) return;
		sending = true;
		const text = details.trim() ? `${reason}: ${details.trim()}` : reason;
		try {
			await reportsApi.report(targetType, targetId, text.slice(0, 500));
			toast.success(m('social.report.sent'));
			onClose();
		} catch (err) {
			toast.error(err instanceof ApiRequestError ? errorMessage(err.code) : errorMessage(null));
		} finally {
			sending = false;
		}
	}

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}
</script>

<svelte:window onkeydown={onKeydown} />

<div
	class="fixed inset-0 z-[100] flex items-end justify-center sm:items-center"
	transition:fade={{ duration: 150 }}
>
	<button
		type="button"
		class="absolute inset-0 bg-black/50 backdrop-blur-sm"
		aria-label={m('common.cancel')}
		onclick={onClose}
	></button>
	<div
		role="dialog"
		aria-modal="true"
		aria-labelledby="report-title"
		class="relative w-full max-w-lg rounded-t-[2rem] bg-surface p-6 pb-8 shadow-2xl sm:rounded-[2rem]"
		transition:fly={{ y: 40, duration: 250 }}
	>
		<form onsubmit={submit} class="space-y-4">
			<div class="mx-auto h-1.5 w-10 rounded-full bg-surface-container-highest sm:hidden"></div>
			<h3 id="report-title" class="font-headline text-lg font-extrabold text-on-surface">
				{title}
			</h3>
			<fieldset class="space-y-2">
				<legend class="mb-2 text-sm text-on-surface-variant">{m('social.report.question')}</legend>
				{#each REASONS as option (option.value)}
					<label
						class="flex cursor-pointer items-center gap-3 rounded-2xl px-4 py-3 transition-colors {reason ===
						option.value
							? 'bg-primary/10 text-on-surface'
							: 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container'}"
					>
						<input
							type="radio"
							name="reason"
							value={option.value}
							bind:group={reason}
							class="accent-primary"
						/>
						<span class="text-sm font-semibold">{m(option.key)}</span>
					</label>
				{/each}
			</fieldset>
			<textarea
				bind:value={details}
				rows="2"
				maxlength="400"
				placeholder={m('social.report.details')}
				class="w-full resize-none rounded-2xl bg-surface-container-highest px-4 py-3 text-sm text-on-surface outline-none placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary/30"
			></textarea>
			<Button type="submit" fullWidth variant="danger" loading={sending} disabled={!reason}>
				{m('social.report.submit')}
			</Button>
		</form>
	</div>
</div>
