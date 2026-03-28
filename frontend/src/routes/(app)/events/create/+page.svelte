<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
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

	async function handleSubmit(e: Event) {
		e.preventDefault();
		error = '';

		if (!date || !time) {
			error = 'Please select a date and time.';
			return;
		}

		const scheduledAt = new Date(`${date}T${time}`).toISOString();

		loading = true;
		try {
			const payload: CreateEventPayload = {
				title,
				scheduledAt,
				visibility,
				maxParticipants
			};
			if (description) payload.description = description;
			if (location) payload.location = location;

			const event = await eventsApi.createEvent(payload);
			toast.success('Event created!');
			goto(`/events/${event.id}`);
		} catch (err) {
			if (err instanceof ApiRequestError) {
				error = err.message;
			} else {
				error = 'Something went wrong. Please try again.';
			}
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Event — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">Create Event</h2>

<form onsubmit={handleSubmit} class="space-y-5 pb-28">
	{#if error}
		<p class="text-sm text-error bg-error-container rounded-xl px-4 py-3">{error}</p>
	{/if}

	<!-- Title -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Event Title *</label>
		<input
			type="text"
			bind:value={title}
			placeholder="e.g. Heavy Euro Night"
			required
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<!-- Date & Time -->
	<div class="grid grid-cols-2 gap-3">
		<div>
			<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Date *</label>
			<input
				type="date"
				bind:value={date}
				required
				min={new Date().toISOString().slice(0, 10)}
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
		</div>
		<div>
			<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Time *</label>
			<input
				type="time"
				bind:value={time}
				required
				class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
			/>
		</div>
	</div>

	<!-- Location -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Location</label>
		<input
			type="text"
			bind:value={location}
			placeholder="Address, venue, or 'Online'"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<!-- Max Players -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Max Players</label>
		<input
			type="number"
			bind:value={maxParticipants}
			min="2"
			max="50"
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm"
		/>
	</div>

	<!-- Visibility -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Visibility</label>
		<div class="flex gap-2">
			{#each [{ value: 'PUBLIC', label: 'Public' }, { value: 'FRIENDS', label: 'Friends' }, { value: 'INVITE_ONLY', label: 'Invite Only' }] as opt}
				<button
					type="button"
					onclick={() => (visibility = opt.value as typeof visibility)}
					class="flex-1 py-2 rounded-xl text-sm font-label font-bold transition-colors {visibility === opt.value ? 'bg-primary text-on-primary' : 'bg-surface-container-high text-on-surface-variant'}"
				>{opt.label}</button>
			{/each}
		</div>
	</div>

	<!-- Description -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Description</label>
		<textarea
			bind:value={description}
			rows="3"
			placeholder="Tell people what to expect..."
			class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
		></textarea>
	</div>

	<!-- Submit -->
	<div class="fixed bottom-0 left-0 right-0 bg-background/80 backdrop-blur-xl px-4 py-4 max-w-lg mx-auto">
		<Button type="submit" fullWidth {loading}>Create Event</Button>
	</div>
</form>
