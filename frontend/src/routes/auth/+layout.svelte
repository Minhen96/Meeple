<script lang="ts">
	// Auth screens: no AppBar or BottomNav. Phones get the narrow centred column. From md up,
	// login and register lay out their own full-page brand + form split (they used to be squeezed
	// into the max-w-sm column and clipped), and the other screens sit in a centred card on the
	// warm auth backdrop (SCREENS_AND_STATES section 16).
	import { page } from '$app/state';
	import { m } from '$lib/i18n';

	interface Props {
		children?: import('svelte').Snippet;
	}
	let { children }: Props = $props();

	const FULL_BLEED = ['/auth/login', '/auth/register'];
	const fullBleed = $derived(FULL_BLEED.some((p) => page.url.pathname.replace(/\/+$/, '') === p));
</script>

{#if fullBleed}
	<div class="min-h-screen bg-background flex items-center justify-center px-4 py-12 md:block md:p-0 md:bg-transparent">
		<div class="w-full max-w-sm md:max-w-none">
			{@render children?.()}
		</div>
	</div>
{:else}
	<div
		class="min-h-screen bg-background md:bg-auth-backdrop flex flex-col items-center justify-center px-4 py-12 md:px-8"
	>
		<a href="/auth/login" class="hidden md:flex items-center gap-2.5 mb-8 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
			<span
				class="w-10 h-10 bg-surface-container-lowest rounded-xl shadow-sm flex items-center justify-center p-2 -rotate-12"
			>
				<img src="/favicon.svg" alt="" class="w-full h-full object-contain" />
			</span>
			<span class="font-headline text-primary font-black tracking-tighter text-2xl">{m('common.appName')}</span>
		</a>
		<div
			class="w-full max-w-sm md:max-w-md md:bg-surface-container-lowest md:rounded-[2rem] md:p-10 md:shadow-[0_12px_32px_rgba(0,0,0,0.06)]"
		>
			{@render children?.()}
		</div>
	</div>
{/if}
