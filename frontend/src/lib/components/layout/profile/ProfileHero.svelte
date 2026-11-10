<script lang="ts">
	// Profile hero (SCREENS_AND_STATES section 8.1): tilted avatar, verified badge, name,
	// @username, location and bio. `actions` renders the buttons row below.
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { m } from '$lib/i18n';
	import type { User } from '$lib/types';

	interface Props {
		user: User;
		actions?: import('svelte').Snippet;
	}

	let { user, actions }: Props = $props();
	const name = $derived(user.displayName || user.username);
</script>

<!-- Phones: centred column. md+: avatar beside the name block, actions under the name. -->
<section class="flex flex-col items-center gap-5 mb-8 pt-4 md:flex-row md:items-center md:gap-8 md:mb-0 md:pt-0">
	<div class="relative md:flex-shrink-0">
		<div class="rotate-3 rounded-2xl overflow-hidden w-28 h-28 md:w-36 md:h-36 shadow-[0_12px_32px_rgba(0,0,0,0.10)] ring-4 ring-surface">
			<Avatar src={user.avatarUrl} {name} size="none" className="w-full h-full rounded-none" />
		</div>
		{#if user.isVerified}
			<span
				class="absolute -bottom-2 -right-2 w-8 h-8 bg-secondary-container rounded-full shadow-md flex items-center justify-center"
				title={m('account.profile.verified')}
			>
				<span class="icon-filled material-symbols-outlined text-on-secondary-container text-[16px]" aria-hidden="true">verified</span>
				<span class="sr-only">{m('account.profile.verified')}</span>
			</span>
		{/if}
	</div>

	<div class="contents md:flex md:flex-col md:gap-5 md:flex-1 md:min-w-0">
	<div class="text-center space-y-1.5 px-4 w-full md:text-left md:px-0">
		<h1 class="text-3xl md:text-4xl font-extrabold font-headline tracking-tight md:break-words">{name}</h1>
		<p class="text-sm text-on-surface-variant">@{user.username}</p>
		{#if user.location}
			<p class="text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant flex items-center justify-center md:justify-start gap-1 opacity-70">
				<span class="material-symbols-outlined text-[14px]" aria-hidden="true">location_on</span>
				{user.location}
			</p>
		{/if}
		{#if user.bio}
			<p class="text-sm text-on-surface-variant max-w-xs mx-auto md:mx-0 md:max-w-md leading-relaxed">{user.bio}</p>
		{/if}
	</div>

	{@render actions?.()}
	</div>
</section>
