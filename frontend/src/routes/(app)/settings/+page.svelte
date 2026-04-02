<script lang="ts">
	import { api } from "$lib/api/client";
	import { goto } from "$app/navigation";
	import { currentUser } from "$lib/stores/auth";

	async function handleLogout() {
		await api.post("/api/v1/auth/logout");
		setUser(null);
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
				},
				{
					label: "Change Password",
					href: "/settings/password",
					icon: "lock",
				},
				{
					label: "BGG Import",
					href: "/settings/bgg",
					icon: "cloud_download",
				},
				{
					label: "Delete Account",
					href: "/settings/delete-account",
					icon: "delete",
					danger: true,
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
							},
							{
								label: "System Health",
								href: null,
								icon: "monitoring",
								action: () => true,
							}, // Placeholder for modal-trigger if needed, or link
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
				},
			],
		},
		{
			title: "About",
			items: [{ label: "App Version 1.0.0", href: null, icon: "info" }],
		},
	]);

	function handleItemClick(item: any) {
		if (item.href) {
			goto(item.href);
		} else if (item.action) {
			// Trigger action
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
	{#each sections as section}
		<div>
			<p
				class="text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant px-1 mb-2"
			>
				{section.title}
			</p>
			<div
				class="bg-surface-container-lowest rounded-xl overflow-hidden shadow-[0_12px_32px_rgba(25,28,29,0.06)]"
			>
				{#each section.items as item, i}
					{#if item.href}
						<a
							href={item.href}
							class="flex items-center gap-3 px-4 py-3.5 hover:bg-surface-container-low transition-colors {i >
							0
								? 'border-t border-outline-variant/10'
								: ''} {item.danger
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
							class="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-surface-container-low transition-colors text-left {i >
							0
								? 'border-t border-outline-variant/10'
								: ''}"
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
