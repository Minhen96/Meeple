<script lang="ts">
	// Step 2 — Profile setup (SCREENS_AND_STATES section 3.3): avatar with 1:1 crop, display
	// name (required), location (optional).
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { toast } from 'svelte-sonner';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import AvatarCropper from '$lib/components/ui/AvatarCropper.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import { ApiRequestError } from '$lib/api/client';
	import { PROFILE_LIMITS, usersApi } from '$lib/api/users';
	import { errorMessage, m } from '$lib/i18n';
	import { setUser } from '$lib/stores/auth';
	import type { User } from '$lib/types';
	import { nextStepPath } from '../onboarding';

	const user = $derived(page.data.user as User | null);
	let displayName = $state('');
	let location = $state('');
	let avatarUrl = $state<string | null>(null);
	let cropFile = $state<File | null>(null);
	let uploading = $state(false);
	let loading = $state(false);
	let error = $state('');
	let fileInput: HTMLInputElement;

	$effect.pre(() => {
		displayName = user?.displayName ?? '';
		location = user?.location ?? '';
		avatarUrl = user?.avatarUrl ?? null;
	});

	const next = nextStepPath('/onboarding/profile') ?? '/';

	function onFilePicked(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		const file = input.files?.[0];
		input.value = '';
		if (file) cropFile = file;
	}

	async function onCropped(file: File) {
		cropFile = null;
		uploading = true;
		try {
			avatarUrl = await usersApi.uploadAvatar(file);
		} catch {
			// SCREENS 3.3: toast and fall back to the placeholder
			avatarUrl = user?.avatarUrl ?? null;
			toast.error(m('account.avatar.uploadFailed'));
		} finally {
			uploading = false;
		}
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!displayName.trim()) return;
		error = '';
		loading = true;
		try {
			const updated = await usersApi.updateMe({
				displayName: displayName.trim(),
				location: location.trim(),
				...(avatarUrl && avatarUrl !== user?.avatarUrl ? { avatarUrl } : {})
			});
			setUser(updated);
			void goto(next);
		} catch (err) {
			error = errorMessage(err instanceof ApiRequestError ? err.code : 'NETWORK_ERROR');
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>{m('account.onboardingProfile.title')} — {m('common.appName')}</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">{m('account.onboardingProfile.title')}</h2>

<form class="space-y-5" onsubmit={handleSubmit}>
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3" role="alert">{error}</p>
	{/if}

	<div class="flex flex-col items-center gap-3">
		<button
			type="button"
			class="relative rounded-full focus:outline-none focus:ring-4 focus:ring-primary/30"
			onclick={() => fileInput.click()}
			disabled={uploading}
			aria-label={m('account.avatar.change')}
		>
			{#if avatarUrl}
				<Avatar src={avatarUrl} name={displayName} size="none" className="w-28 h-28" />
			{:else}
				<span class="w-28 h-28 rounded-full bg-primary-fixed flex items-center justify-center">
					<img src="/favicon.svg" alt="" class="w-14 h-14 opacity-70" />
				</span>
			{/if}
			<span class="absolute bottom-0 right-0 w-9 h-9 rounded-full bg-primary text-on-primary flex items-center justify-center shadow-md">
				<span class="material-symbols-outlined text-[18px]" aria-hidden="true">photo_camera</span>
			</span>
			{#if uploading}
				<span class="absolute inset-0 rounded-full bg-black/40 flex items-center justify-center">
					<span class="material-symbols-outlined text-white animate-spin text-2xl">progress_activity</span>
				</span>
			{/if}
		</button>
		<input
			bind:this={fileInput}
			type="file"
			accept="image/jpeg,image/png,image/webp"
			onchange={onFilePicked}
			class="hidden"
		/>
		<p class="text-xs text-on-surface-variant">{m('account.onboardingProfile.avatarHint')}</p>
	</div>

	<div>
		<label for="onb-display-name" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			{m('account.profile.displayName')}
		</label>
		<input
			id="onb-display-name"
			type="text"
			bind:value={displayName}
			required
			maxlength={PROFILE_LIMITS.displayNameMax}
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<div>
		<label for="onb-location" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			{m('account.profile.location')}
		</label>
		<input
			id="onb-location"
			type="text"
			bind:value={location}
			maxlength={PROFILE_LIMITS.locationMax}
			placeholder={m('account.profile.locationPlaceholder')}
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<Button type="submit" {loading} fullWidth disabled={!displayName.trim() || uploading}>
		{m('common.continue')}
	</Button>
	<a href={next} class="block text-center text-sm text-on-surface-variant">{m('common.skip')}</a>
</form>

{#if cropFile}
	<AvatarCropper file={cropFile} onCancel={() => (cropFile = null)} onCropped={onCropped} />
{/if}
