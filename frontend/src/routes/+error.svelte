<script lang="ts">
	// Localized error page. Load functions pass English developer messages to error();
	// the user sees a translated message chosen by status instead.
	import { page } from '$app/stores';
	import { m } from '$lib/i18n';

	const notFound = $derived($page.status === 404);
</script>

<svelte:head><title>{m(notFound ? 'common.error.notFoundTitle' : 'common.error.title')} — Meeple</title></svelte:head>

<main class="min-h-screen bg-background flex flex-col items-center justify-center gap-4 px-6 text-center">
	<span class="material-symbols-outlined text-6xl text-primary/30">
		{notFound ? 'search_off' : 'error'}
	</span>
	<h1 class="font-headline text-2xl font-extrabold text-on-surface">
		{m(notFound ? 'common.error.notFoundTitle' : 'common.error.title')}
	</h1>
	<p class="max-w-xs text-sm text-on-surface-variant">
		{m(notFound ? 'errors.notFound' : 'errors.unknown')}
	</p>
	<a
		href="/"
		class="rounded-full bg-gradient-to-r from-primary to-primary-container px-7 py-3 font-headline font-bold text-on-primary transition-all active:scale-95"
	>
		{m('common.error.home')}
	</a>
</main>
