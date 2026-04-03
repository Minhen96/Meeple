<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
	import Avatar from '$lib/components/ui/Avatar.svelte';
	import { usersApi } from '$lib/api/users';
	import { setUser } from '$lib/stores/auth';
	import { ApiRequestError } from '$lib/api/client';
	import type { PageData } from './$types';

	interface Props { data: PageData }
	let { data }: Props = $props();

	let displayName = $state(data.user?.displayName ?? '');
	let bio = $state(data.user?.bio ?? '');
	let location = $state(data.user?.location ?? '');
	let avatarUrl = $state(data.user?.avatarUrl ?? null);
	let loading = $state(false);
	let avatarUploading = $state(false);
	let error = $state('');

	let fileInput: HTMLInputElement;

	async function handleAvatarChange(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		if (!file) return;

		avatarUploading = true;
		error = '';
		try {
			const form = new FormData();
			form.append('file', file);
			const res = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/upload/avatar`, {
				method: 'POST',
				credentials: 'include',
				body: form
			});
			if (!res.ok) throw new Error('Upload failed');
			const body = await res.json();
			// ResponseWrappingAdvice wraps plain Map responses in { data: {...} }
			avatarUrl = body.data?.publicUrl ?? body.publicUrl;
		} catch {
			error = 'Failed to upload photo. Please try again.';
		} finally {
			avatarUploading = false;
		}
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		loading = true;
		try {
			const updated = await usersApi.updateMe({
				displayName: displayName || undefined,
				bio: bio || undefined,
				location: location || undefined,
				avatarUrl: avatarUrl ?? undefined
			});
			setUser(updated);
			history.back();
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = 'Something went wrong.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Edit Profile — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<button onclick={() => history.back()} class="text-on-surface-variant" aria-label="Back">
		<span class="material-symbols-outlined">arrow_back</span>
	</button>
	<h2 class="text-xl font-extrabold font-headline">Edit Profile</h2>
</div>

<form onsubmit={handleSubmit} class="space-y-4">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<!-- Avatar -->
	<div class="flex flex-col items-center gap-3 py-2">
		<div class="relative">
			<Avatar
				src={avatarUrl}
				name={displayName || data.user?.username || '?'}
				size="none"
				class="w-24 h-24 rounded-full object-cover"
			/>
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
			Change Photo
		</button>
		<input
			bind:this={fileInput}
			type="file"
			accept="image/jpeg,image/png,image/webp"
			onchange={handleAvatarChange}
			class="hidden"
		/>
	</div>

	<div>
		<label for="displayName" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Display Name
		</label>
		<input
			id="displayName"
			type="text"
			bind:value={displayName}
			placeholder="Your name"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<div>
		<label for="bio" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Bio
		</label>
		<textarea
			id="bio"
			bind:value={bio}
			rows="3"
			placeholder="Tell people about yourself..."
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
		></textarea>
	</div>

	<div>
		<label for="location" class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Location
		</label>
		<input
			id="location"
			type="text"
			bind:value={location}
			placeholder="City, Country"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<Button type="submit" {loading} fullWidth>Save Changes</Button>
</form>
