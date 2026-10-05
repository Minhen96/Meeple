<script lang="ts">
	import { authApi } from "$lib/api/auth";
	import { goto } from "$app/navigation";
	import { currentUser } from "$lib/stores/auth";
	import { clearClientSession } from "$lib/session";
	import SetupStatusModal from "$lib/components/admin/SetupStatusModal.svelte";

	let showSetupModal = $state(false);

	async function handleLogout() {
		try {
			await authApi.logout();
		} catch {
			// clear local state regardless — the server session expires on its own
		}
		clearClientSession();
		goto("/auth/login");
	}

	const sections = $derived([
		{
			title: "Account",
			items: [
				{
					label: "Edit Profile",
					href: "/settings/profile",
					icon: "person",
					danger: false,
					action: undefined
				},
				{
					label: "Change Password",
					href: "/settings/password",
					icon: "lock",
					danger: false,
					action: undefined
				},
				{
					label: "BGG Import",
					href: "/settings/bgg",
					icon: "cloud_download",
					danger: false,
					action: undefined
				},
				{
					label: "Delete Account",
					href: "/settings/delete-account",
					icon: "delete",
					danger: true,
					action: undefined
				},
			],
		},
		...($currentUser?.isAdmin
			? [
					{
						title: "Management",
						items: [
							{
								label: "Review Queue",
								href: "/admin/rulebooks",
								icon: "rate_review",
								danger: false,
								action: undefined
							},
							{
								label: "System Health",
								href: "/admin/health",
								icon: "monitoring",
								danger: false,
								action: undefined
							},
							{
								label: "Boardgame Rules Import",
								href: null,
								icon: "settings_suggest",
								danger: false,
								action: () => (showSetupModal = true),
							},
							{
								label: "Promote Admin",
								href: "/settings/management",
								icon: "person_add",
								danger: false,
								action: undefined
							},
						],
					},
				]
			: []),
		{
			title: "Notifications",
			items: [
				{
					label: "Notification Preferences",
					href: "/settings/notifications",
					icon: "notifications",
					danger: false,
					action: undefined
				},
			],
		},
		{
			title: "About",
			items: [
				{
					label: "App Version 1.0.0",
					href: null,
					icon: "info",
					danger: false,
					action: undefined
				}
			],
		},
	]);

	interface SettingsItem {
		href: string | null;
		action: (() => void) | undefined;
	}

	function handleItemClick(item: SettingsItem) {
		if (item.href) {
			goto(item.href);
		} else if (item.action) {
			item.action();
		}
	}
</script>

<svelte:head><title>Settings — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-8 mt-3">
	<button
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
		aria-label="Back"
	>
		<span class="material-symbols-outlined text-[22px]">arrow_back</span>
	</button>
	<h2 class="text-2xl font-extrabold font-headline">Settings</h2>
</div>

<div class="space-y-6">
	{#each sections as section (section.title)}
		<div>
			<p
				class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant px-1 mb-2"
			>
				{section.title}
			</p>
			<div
				class="bg-surface-container-low rounded-xl overflow-hidden p-1 space-y-1 shadow-[0_12px_32px_rgba(25,28,29,0.06)]"
			>
				{#each section.items as item (item.label)}
					{#if item.href}
						<a
							href={item.href}
							class="flex items-center gap-3 px-4 py-3.5 rounded-lg bg-surface-container-lowest hover:bg-surface-container transition-colors {item.danger
								? 'text-error'
								: 'text-on-surface'}"
						>
							<span
								class="material-symbols-outlined text-[20px] {item.danger
									? 'text-error'
									: 'text-on-surface-variant'}"
								>{item.icon}</span
							>
							<span class="flex-1 text-sm font-medium"
								>{item.label}</span
							>
							<span
								class="material-symbols-outlined text-[16px] text-on-surface-variant"
								>chevron_right</span
							>
						</a>
					{:else}
						<button
							onclick={() => handleItemClick(item)}
							class="w-full flex items-center gap-3 px-4 py-3.5 rounded-lg bg-surface-container-lowest hover:bg-surface-container transition-colors text-left"
						>
							<span
								class="material-symbols-outlined text-[20px] text-on-surface-variant"
								>{item.icon}</span
							>
							<span class="flex-1 text-sm text-on-surface"
								>{item.label}</span
							>
							{#if item.action}
								<span
									class="material-symbols-outlined text-[16px] text-on-surface-variant"
									>chevron_right</span
								>
							{/if}
						</button>
					{/if}
				{/each}
			</div>
		</div>
	{/each}

	<button
		onclick={handleLogout}
		class="w-full text-center py-3.5 text-error font-semibold text-sm"
	>
		Log Out
	</button>
</div>

{#if showSetupModal}
	<SetupStatusModal onClose={() => (showSetupModal = false)} />
{/if}
