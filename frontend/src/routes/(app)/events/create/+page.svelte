<script lang="ts">
	import { eventsApi, type CreateEventPayload } from '$lib/api/events';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';

	let title = $state('');
	let description = $state('');
	let location = $state('');
	let date = $state('');
	let time = $state('');
	let maxParticipants = $state(8);
	let visibility = $state<'PUBLIC' | 'FRIENDS' | 'INVITE_ONLY'>('PUBLIC');
	let loading = $state(false);
	let error = $state('');

	const visibilityOptions = [
		{ value: 'PUBLIC',       label: 'Public',      icon: 'public' },
		{ value: 'FRIENDS',      label: 'Friends',     icon: 'group' },
		{ value: 'INVITE_ONLY',  label: 'Invite Only', icon: 'lock' }
	] as const;

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';
		if (!title.trim()) { error = 'Please add an event title.'; return; }
		if (!date || !time) { error = 'Please select a date and time.'; return; }

		const scheduledAt = new Date(`${date}T${time}`).toISOString();
		loading = true;
		try {
			const payload: CreateEventPayload = { title: title.trim(), scheduledAt, visibility, maxParticipants };
			if (description) payload.description = description;
			if (location) payload.location = location;
			const event = await eventsApi.createEvent(payload);
			toast.success('Event created!');
			goto(`/events/${event.id}`);
		} catch (err) {
			error = err instanceof ApiRequestError ? err.message : 'Something went wrong. Please try again.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Event — Meeple & Hearth</title></svelte:head>

<!-- Page header -->
<div class="mb-6 space-y-1">
	<h2 class="text-3xl font-headline font-extrabold tracking-tight">Host a Game Night</h2>
	<p class="text-sm text-on-surface-variant">Bring people together around the table.</p>
</div>

<form onsubmit={handleSubmit} class="space-y-5 pb-28">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<!-- Title -->
	<div>
		<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Event Title *
		</label>
		<input
			type="text"
			bind:value={title}
			placeholder="e.g. Heavy Euro Night"
			required
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<!-- Date & Time bento -->
	<div class="grid grid-cols-2 gap-3">
		<div class="bg-surface-container-low rounded-xl px-4 py-3 space-y-1">
			<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant">
				Date *
			</label>
			<div class="flex items-center gap-2">
				<span class="material-symbols-outlined text-primary text-[18px]">calendar_today</span>
				<input
					type="date"
					bind:value={date}
					required
					min={new Date().toISOString().slice(0, 10)}
					class="flex-1 bg-transparent text-on-surface focus:outline-none font-body text-sm min-w-0"
				/>
			</div>
		</div>
		<div class="bg-surface-container-low rounded-xl px-4 py-3 space-y-1">
			<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant">
				Time *
			</label>
			<div class="flex items-center gap-2">
				<span class="material-symbols-outlined text-primary text-[18px]">schedule</span>
				<input
					type="time"
					bind:value={time}
					required
					class="flex-1 bg-transparent text-on-surface focus:outline-none font-body text-sm min-w-0"
				/>
			</div>
		</div>
	</div>

	<!-- Location -->
	<div class="flex items-center gap-3 bg-surface-container-low rounded-xl px-4 py-3">
		<span class="material-symbols-outlined text-primary text-[20px]">location_on</span>
		<input
			type="text"
			bind:value={location}
			placeholder="Address, venue, or 'Online'"
			class="flex-1 bg-transparent text-on-surface placeholder:text-on-surface-variant focus:outline-none font-body text-sm"
		/>
	</div>

	<!-- Max players -->
	<div class="flex items-center gap-3 bg-surface-container-low rounded-xl px-4 py-3">
		<span class="material-symbols-outlined text-primary text-[20px]">group</span>
		<div class="flex-1">
			<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mb-1">
				Max Players
			</label>
			<input
				type="number"
				bind:value={maxParticipants}
				min="2"
				max="50"
				class="bg-transparent text-on-surface focus:outline-none font-body text-sm w-16"
			/>
		</div>
	</div>

	<!-- Visibility -->
	<div>
		<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mb-3">
			Visibility
		</label>
		<div class="flex gap-2">
			{#each visibilityOptions as opt}
				<button
					type="button"
					onclick={() => (visibility = opt.value)}
					class="flex-1 flex flex-col items-center gap-1 py-3 rounded-xl text-xs font-label font-bold transition-all
						{visibility === opt.value
							? 'bg-primary text-on-primary shadow-lg shadow-primary/20'
							: 'bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest'}"
				>
					<span class="material-symbols-outlined text-[18px]">{opt.icon}</span>
					{opt.label}
				</button>
			{/each}
		</div>
	</div>

	<!-- Description -->
	<div>
		<label class="block text-[10px] font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">
			Description
		</label>
		<textarea
			bind:value={description}
			rows="3"
			placeholder="Tell people what to expect..."
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
		></textarea>
	</div>

	<!-- Submit -->
	<div class="fixed bottom-0 left-0 right-0 bg-background/80 backdrop-blur-xl px-4 py-4 max-w-lg mx-auto">
		<button
			type="submit"
			disabled={loading}
			class="w-full py-3.5 bg-gradient-to-r from-primary to-secondary text-on-primary rounded-2xl font-label font-bold text-sm shadow-lg shadow-primary/25 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
		>
			<span class="material-symbols-outlined text-[18px]">rocket_launch</span>
			{loading ? 'Creating…' : 'Create Event'}
		</button>
	</div>
</form>
