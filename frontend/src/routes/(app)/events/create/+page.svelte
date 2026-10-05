<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { toast } from 'svelte-sonner';
	import { eventsApi } from '$lib/api/events';
	import { matchesApi } from '$lib/api/matches';
	import { m } from '$lib/i18n';
	import EventForm from '$lib/components/event/EventForm.svelte';
	import { emptyForm, toCreatePayload, toDateInput, toTimeInput, type EventFormValues } from '$lib/components/event/eventForm';
	import { eventErrorMessage } from '$lib/components/event/eventState';

	let values = $state<EventFormValues>(emptyForm());
	let submitting = $state(false);
	let error = $state<string | null>(null);
	let fromMatch = $state(false);

	// ?matchGroupId=… pre-fills game, time and the other members (SCREENS section 6.5)
	onMount(async () => {
		const groupId = page.url.searchParams.get('matchGroupId');
		if (!groupId) return;
		try {
			const group = (await matchesApi.getSuggestions()).find((g) => g.id === groupId);
			if (!group) return;
			const start = group.overlapStart ? new Date(group.overlapStart) : null;
			values = {
				...values,
				game: { id: group.game.id, title: group.game.title, thumbnailUrl: group.game.thumbnailUrl },
				title: `${group.game.title} Night`.slice(0, 100),
				date: start && start.getTime() > Date.now() ? toDateInput(start) : values.date,
				time: start && start.getTime() > Date.now() ? toTimeInput(start) : values.time,
				invitedUserIds: group.members.map((u) => u.id).filter((id) => id !== page.data.user?.id)
			};
			fromMatch = true;
		} catch {
			// Pre-fill is a convenience; the empty form still works
		}
	});

	async function submit(formValues: EventFormValues) {
		submitting = true;
		error = null;
		try {
			const payload = toCreatePayload(formValues);
			const created = await eventsApi.createEvent(payload);
			toast.success(payload.invitedUserIds?.length ? m('event.toast.created') : m('event.toast.createdNoInvites'));
			await goto(`/events/${created.id}`);
		} catch (err) {
			error = eventErrorMessage(err);
		} finally {
			submitting = false;
		}
	}
</script>

<svelte:head><title>{m('event.form.createTitle')} — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6 mt-3">
	<button
		type="button"
		onclick={() => history.back()}
		class="w-11 h-11 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface hover:bg-surface-container-high transition-all spring-bounce"
		aria-label={m('event.detail.back')}
	>
		<span class="material-symbols-outlined text-[24px]" aria-hidden="true">arrow_back</span>
	</button>
	<div class="flex-1">
		<h2 class="text-2xl font-black font-headline tracking-tight text-on-surface">{m('event.form.createTitle')}</h2>
		<p class="text-[11px] font-label font-bold text-on-surface-variant uppercase tracking-widest">
			{fromMatch ? m('event.form.fromMatch') : m('event.form.createSubtitle')}
		</p>
	</div>
</div>

<EventForm bind:values mode="create" {error} {submitting} onSubmit={submit} />
