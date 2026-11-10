<script lang="ts">
	// Settings root. The menu itself lives in the settings layout (it is this screen on phones);
	// from lg, where the menu is a persistent left column, this fills the right pane with an
	// account summary until a setting is picked.
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { m, type MessageKey } from '$lib/i18n';
	import { currentUser } from '$lib/stores/auth';

	const shortcuts: { href: string; icon: string; label: MessageKey }[] = [
		{ href: '/settings/profile', icon: 'person', label: 'account.settings.editProfile' },
		{ href: '/settings/notifications', icon: 'notifications', label: 'account.settings.notificationPrefs' },
		{ href: '/settings/sessions', icon: 'devices', label: 'account.settings.sessions' }
	];
</script>

<svelte:head><title>{m('account.settings.title')} — {m('common.appName')}</title></svelte:head>

<section class="mt-3 rounded-lg bg-surface-container-low p-8 space-y-8">
	{#if $currentUser}
		<div class="flex items-center gap-5">
			<Avatar
				src={$currentUser.avatarUrl}
				name={$currentUser.displayName ?? $currentUser.username}
				size="none"
				className="w-20 h-20 text-2xl"
			/>
			<div class="min-w-0">
				<p class="text-2xl font-extrabold font-headline tracking-tight text-on-surface truncate">
					{$currentUser.displayName ?? $currentUser.username}
				</p>
				<p class="text-sm text-on-surface-variant truncate">@{$currentUser.username}</p>
				{#if $currentUser.email}
					<p class="text-sm text-on-surface-variant truncate">{$currentUser.email}</p>
				{/if}
			</div>
		</div>
	{/if}

	<p class="text-sm text-on-surface-variant">{m('account.settings.overviewHint')}</p>

	<div class="grid grid-cols-1 xl:grid-cols-3 gap-3">
		{#each shortcuts as shortcut (shortcut.href)}
			<a
				href={shortcut.href}
				class="flex xl:flex-col items-center xl:items-start gap-3 rounded-xl bg-surface-container-lowest p-4 xl:p-5 text-on-surface hover:bg-surface-container transition-colors"
			>
				<span
					class="w-10 h-10 rounded-full bg-primary-fixed text-primary flex items-center justify-center flex-shrink-0"
				>
					<span class="material-symbols-outlined text-[20px]">{shortcut.icon}</span>
				</span>
				<span class="text-sm font-bold">{m(shortcut.label)}</span>
			</a>
		{/each}
	</div>
</section>
