<script lang="ts">
	// BoardGameGeek collection import (SCREENS_AND_STATES section 3.4), used by onboarding and
	// Settings. Starts the import, polls every 2s, then shows the result or a mapped error.
	import { onDestroy, onMount } from 'svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import ProgressBar from '$lib/components/ui/ProgressBar.svelte';
	import { gamesApi } from '$lib/api/games';
	import { m } from '$lib/i18n';
	import { createBggImportPoller, progressPercent, type BggImportView } from './bggImport';

	interface Props {
		/** 'onboarding' shows the "skip and retry in Settings" wording for an unavailable BGG. */
		context: 'onboarding' | 'settings';
		initialUsername?: string | null;
		/** Shown after a successful import (e.g. Continue). */
		done?: import('svelte').Snippet;
	}

	let { context, initialUsername = null, done }: Props = $props();

	let username = $state('');
	let view = $state<BggImportView>({ phase: 'idle' });

	const poller = createBggImportPoller(gamesApi, (next) => (view = next));

	onMount(() => {
		username = initialUsername ?? '';
		// Pick up an import that is still running (page reload, back navigation)
		gamesApi
			.getBggImportStatus()
			.then((status) => {
				if (status.status === 'running') void poller.resume();
			})
			.catch(() => {});
	});
	onDestroy(() => poller.stop());

	const running = $derived(view.phase === 'running');

	function errorText(code: string): string {
		switch (code) {
			case 'BGG_USER_NOT_FOUND':
				return m('library.bgg.error.notFound');
			case 'BGG_IMPORT_IN_PROGRESS':
				return m('library.bgg.error.inProgress');
			default:
				return context === 'onboarding'
					? m('library.bgg.error.unavailable')
					: m('library.bgg.error.unavailableSettings');
		}
	}

	function submit(e: Event) {
		e.preventDefault();
		if (!username.trim() || running) return;
		void poller.start(username);
	}
</script>

{#if view.phase === 'done'}
	<div class="space-y-5">
		<div class="flex items-center gap-3">
			<span class="icon-filled material-symbols-outlined text-tertiary text-[32px]">check_circle</span>
			<p class="text-lg font-extrabold font-headline text-on-surface">
				{view.status.imported > 0
					? m('library.bgg.success', { count: view.status.imported })
					: m('library.bgg.successNone')}
			</p>
		</div>
		{#if view.status.skipped > 0}
			<p class="text-sm text-on-surface-variant">{m('library.bgg.skipped', { count: view.status.skipped })}</p>
		{/if}
		{#if view.status.preview.length > 0}
			<div class="flex gap-3 overflow-x-auto hide-scrollbar pb-1">
				{#each view.status.preview as game (game.gameId)}
					<a href="/library/{game.gameId}" class="shrink-0 w-20 space-y-1">
						{#if game.thumbnailUrl}
							<img
								src={game.thumbnailUrl}
								alt={game.title}
								class="w-20 h-24 rounded-xl object-cover bg-surface-container-high"
								loading="lazy"
							/>
						{:else}
							<div class="w-20 h-24 rounded-xl bg-surface-container-high flex items-center justify-center">
								<span class="material-symbols-outlined text-on-surface-variant">casino</span>
							</div>
						{/if}
						<p class="text-[11px] font-bold text-on-surface line-clamp-2 leading-tight">{game.title}</p>
					</a>
				{/each}
			</div>
		{/if}
		{#if done}
			{@render done()}
		{:else}
			<Button variant="secondary" fullWidth onclick={() => (view = { phase: 'idle' })}>
				{m('library.bgg.importAgain')}
			</Button>
		{/if}
	</div>
{:else}
	<form onsubmit={submit} class="space-y-4">
		{#if view.phase === 'failed'}
			<p class="text-sm text-on-error-container bg-error-container rounded-xl px-4 py-3" role="alert">
				{errorText(view.errorCode)}
			</p>
		{/if}

		<label class="block space-y-2">
			<span class="text-xs font-bold uppercase tracking-widest text-on-surface-variant">
				{m('library.bgg.username')}
			</span>
			<input
				type="text"
				autocomplete="username"
				maxlength="50"
				bind:value={username}
				disabled={running}
				placeholder={m('library.bgg.username')}
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm disabled:opacity-60"
			/>
		</label>
		<p class="text-xs text-on-surface-variant px-1">{m('library.bgg.privacy')}</p>

		{#if view.phase === 'running'}
			<div class="space-y-2" aria-live="polite">
				<p class="text-sm font-bold text-on-surface">
					{view.status && view.status.total > 0
						? m('library.bgg.importing', { processed: view.status.processed, total: view.status.total })
						: m('library.bgg.starting')}
				</p>
				<ProgressBar value={progressPercent(view.status)} label={m('library.bgg.starting')} />
			</div>
		{/if}

		<Button type="submit" fullWidth loading={running} disabled={!username.trim()}>
			{m('library.bgg.import')}
		</Button>
	</form>
{/if}
