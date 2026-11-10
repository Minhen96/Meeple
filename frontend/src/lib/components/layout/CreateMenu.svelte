<script lang="ts">
	// Rail / sidebar "Create" button (md and up): the same options as the mobile create sheet,
	// as a popover menu. Arrow keys move between items; Escape, Tab or an outside click close it.
	import { tick } from 'svelte';
	import { scale } from 'svelte/transition';
	import { m } from '$lib/i18n';
	import { motionDuration } from '$lib/utils/media';
	import { CREATE_ACTIONS } from './shell';

	let open = $state(false);
	let root: HTMLDivElement;
	let trigger: HTMLButtonElement;
	let menu = $state<HTMLDivElement>();

	function items(): HTMLElement[] {
		return Array.from(menu?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
	}

	async function show() {
		open = true;
		await tick();
		items()[0]?.focus();
	}

	function hide(restoreFocus = false) {
		open = false;
		if (restoreFocus) trigger?.focus();
	}

	function toggle() {
		if (open) hide();
		else void show();
	}

	function onTriggerKeydown(event: KeyboardEvent) {
		if (event.key === 'ArrowDown' && !open) {
			event.preventDefault();
			void show();
		}
	}

	function onMenuKeydown(event: KeyboardEvent) {
		const list = items();
		const index = list.indexOf(document.activeElement as HTMLElement);
		const focusAt = (i: number) => list[(i + list.length) % list.length]?.focus();
		switch (event.key) {
			case 'ArrowDown':
				event.preventDefault();
				focusAt(index + 1);
				break;
			case 'ArrowUp':
				event.preventDefault();
				focusAt(index - 1);
				break;
			case 'Home':
				event.preventDefault();
				focusAt(0);
				break;
			case 'End':
				event.preventDefault();
				focusAt(list.length - 1);
				break;
			case 'Escape':
				event.preventDefault();
				event.stopPropagation();
				hide(true);
				break;
			case 'Tab':
				hide();
				break;
		}
	}

	function onWindowPointerDown(event: PointerEvent) {
		if (open && event.target instanceof Node && !root.contains(event.target)) hide();
	}
</script>

<svelte:window onpointerdown={onWindowPointerDown} />

<div bind:this={root} class="relative">
	<button
		bind:this={trigger}
		type="button"
		onclick={toggle}
		onkeydown={onTriggerKeydown}
		class="mx-auto lg:mx-0 w-12 h-12 lg:w-full lg:h-auto lg:py-3 lg:px-5 flex items-center justify-center lg:justify-start gap-2 rounded-full bg-gradient-to-br from-primary to-primary-container text-on-primary font-headline font-bold shadow-[0_8px_24px_rgba(137,81,0,0.25)] transition-transform hover:-translate-y-0.5 active:scale-95 motion-reduce:transition-none motion-reduce:hover:translate-y-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-surface-container-low"
		aria-label={m('common.create.title')}
		aria-haspopup="menu"
		aria-expanded={open}
		title={m('common.create.title')}
	>
		<span class="material-symbols-outlined text-2xl" aria-hidden="true">add</span>
		<span class="hidden lg:inline">{m('common.create.title')}</span>
	</button>

	{#if open}
		<div
			bind:this={menu}
			role="menu"
			tabindex="-1"
			aria-label={m('common.create.title')}
			onkeydown={onMenuKeydown}
			class="absolute left-full top-0 ml-3 z-50 w-72 rounded-[1.5rem] bg-surface-container-lowest/95 backdrop-blur-xl border border-white/10 shadow-[0_12px_32px_rgba(0,0,0,0.12)] p-2 origin-top-left"
			transition:scale={{ start: 0.95, duration: motionDuration(150) }}
		>
			{#each CREATE_ACTIONS as action (action.href)}
				<a
					href={action.href}
					role="menuitem"
					tabindex="-1"
					onclick={() => hide()}
					class="flex items-center gap-3 rounded-2xl p-3 hover:bg-surface-container-low focus-visible:bg-surface-container-low focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary transition-colors"
				>
					<span
						class="w-10 h-10 shrink-0 rounded-full bg-secondary-container text-on-secondary-container flex items-center justify-center"
					>
						<span class="material-symbols-outlined text-[22px]" aria-hidden="true">{action.icon}</span>
					</span>
					<span class="min-w-0">
						<span class="block font-headline font-bold text-on-surface">{m(action.label)}</span>
						<span class="block text-xs text-on-surface-variant leading-snug">{m(action.hint)}</span>
					</span>
				</a>
			{/each}
		</div>
	{/if}
</div>
