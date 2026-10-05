<script lang="ts">
	// Edit profile (SCREENS_AND_STATES section 11.2): avatar, display name, username (once per
	// 30 days), bio with a 200-character counter, location; sticky Save.
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import AvatarCropper from '$lib/components/ui/AvatarCropper.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import { ApiRequestError } from '$lib/api/client';
	import { PROFILE_LIMITS, usernameProblem, usersApi, type UpdateProfilePayload } from '$lib/api/users';
	import { errorMessage, getLocale, m } from '$lib/i18n';
	import { setUser } from '$lib/stores/auth';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	let displayName = $state('');
	let username = $state('');
	let bio = $state('');
	let location = $state('');
	let avatarUrl = $state<string | null>(null);
	let loading = $state(false);
	let avatarUploading = $state(false);
	let error = $state('');
	let cropFile = $state<File | null>(null);
	let fileInput: HTMLInputElement;

	$effect.pre(() => {
		displayName = data.user?.displayName ?? '';
		username = data.user?.username ?? '';
		bio = data.user?.bio ?? '';
		location = data.user?.location ?? '';
		avatarUrl = data.user?.avatarUrl ?? null;
	});

	const changeAvailableAt = $derived(data.user?.usernameChangeAvailableAt ?? null);
	const usernameLocked = $derived(changeAvailableAt !== null);
	const usernameError = $derived.by(() => {
		if (username === data.user?.username) return null;
		const problem = usernameProblem(username);
		return problem ? m(`account.username.${problem}`) : null;
	});
	const displayNameError = $derived(
		displayName.trim().length === 0 ? m('account.profile.displayNameRequired') : null
	);

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString(getLocale(), { year: 'numeric', month: 'short', day: 'numeric' });
	}

	function onFilePicked(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		const file = input.files?.[0];
		input.value = '';
		if (file) cropFile = file;
	}

	async function onCropped(file: File) {
		cropFile = null;
		avatarUploading = true;
		error = '';
		try {
			avatarUrl = await usersApi.uploadAvatar(file);
		} catch (err) {
			toast.error(
				err instanceof ApiRequestError && err.code === 'FILE_TOO_LARGE'
					? errorMessage(err.code)
					: m('account.avatar.uploadFailed')
			);
		} finally {
			avatarUploading = false;
		}
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (displayNameError || usernameError) return;
		error = '';
		loading = true;
		const payload: UpdateProfilePayload = {
			displayName: displayName.trim(),
			bio: bio.trim(),
			location: location.trim()
		};
		if (avatarUrl && avatarUrl !== data.user?.avatarUrl) payload.avatarUrl = avatarUrl;
		if (!usernameLocked && username !== data.user?.username) payload.username = username;
		try {
			const updated = await usersApi.updateMe(payload);
			setUser(updated);
			toast.success(m('account.profile.saved'));
			void goto('/profile', { invalidateAll: true });
		} catch (err) {
			error = errorMessage(err instanceof ApiRequestError ? err.code : null);
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>{m('account.profile.editTitle')} — {m('common.appName')}</title></svelte:head>

<PageHeader title={m('account.profile.editTitle')} />

<form onsubmit={handleSubmit} class="space-y-5 pb-24" novalidate>
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3" role="alert">{error}</p>
	{/if}

	<div class="flex flex-col items-center gap-3 py-2">
		<div class="relative">
			<Avatar src={avatarUrl} name={displayName || username} size="none" className="w-24 h-24" />
			{#if avatarUploading}
				<div class="absolute inset-0 rounded-full bg-black/40 flex items-center justify-center">
					<span class="material-symbols-outlined text-white animate-spin text-2xl">progress_activity</span>
				</div>
			{/if}
		</div>
		<button
			type="button"
			onclick={() => fileInput.click()}
			disabled={avatarUploading}
			class="text-sm font-semibold text-primary hover:underline disabled:opacity-40"
		>
			{m('account.avatar.change')}
		</button>
		<input
			bind:this={fileInput}
			type="file"
			accept="image/jpeg,image/png,image/webp"
			onchange={onFilePicked}
			class="hidden"
		/>
	</div>

	<div>
		<label for="displayName" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			{m('account.profile.displayName')}
		</label>
		<input
			id="displayName"
			type="text"
			bind:value={displayName}
			maxlength={PROFILE_LIMITS.displayNameMax}
			required
			aria-invalid={displayNameError ? 'true' : undefined}
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
		{#if displayNameError}
			<p class="text-xs text-error mt-1 px-1">{displayNameError}</p>
		{/if}
	</div>

	<div>
		<label for="username" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			{m('account.profile.username')}
		</label>
		<div class="relative">
			<span class="absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant text-sm">@</span>
			<input
				id="username"
				type="text"
				bind:value={username}
				disabled={usernameLocked}
				maxlength={PROFILE_LIMITS.usernameMax}
				autocapitalize="none"
				autocomplete="username"
				aria-invalid={usernameError ? 'true' : undefined}
				class="w-full bg-surface-container-highest rounded-xl pl-8 pr-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm disabled:opacity-60"
			/>
		</div>
		{#if usernameLocked && changeAvailableAt}
			<p class="text-xs text-on-surface-variant mt-1 px-1">
				{m('account.username.availableOn', { date: formatDate(changeAvailableAt) })}
			</p>
		{:else if usernameError}
			<p class="text-xs text-error mt-1 px-1">{usernameError}</p>
		{:else}
			<p class="text-xs text-on-surface-variant mt-1 px-1">{m('account.username.onceEvery30Days')}</p>
		{/if}
	</div>

	<div>
		<label for="bio" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			{m('account.profile.bio')}
		</label>
		<textarea
			id="bio"
			bind:value={bio}
			rows="3"
			maxlength={PROFILE_LIMITS.bioMax}
			placeholder={m('account.profile.bioPlaceholder')}
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
		></textarea>
		<p class="text-xs text-right mt-1 px-1 {bio.length >= PROFILE_LIMITS.bioMax ? 'text-error' : 'text-on-surface-variant'}">
			{bio.length}/{PROFILE_LIMITS.bioMax}
		</p>
	</div>

	<div>
		<label for="location" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			{m('account.profile.location')}
		</label>
		<input
			id="location"
			type="text"
			bind:value={location}
			maxlength={PROFILE_LIMITS.locationMax}
			placeholder={m('account.profile.locationPlaceholder')}
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<div class="fixed bottom-0 inset-x-0 z-40 bg-surface/90 backdrop-blur-xl px-4 pt-3 pb-[calc(env(safe-area-inset-bottom)+0.75rem)]">
		<div class="max-w-lg mx-auto">
			<Button type="submit" {loading} fullWidth disabled={!!displayNameError || !!usernameError}>
				{m('common.save')}
			</Button>
		</div>
	</div>
</form>

{#if cropFile}
	<AvatarCropper file={cropFile} onCancel={() => (cropFile = null)} onCropped={onCropped} />
{/if}
