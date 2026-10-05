<script lang="ts">
	import { untrack } from 'svelte';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { eventsApi } from '$lib/api/events';
	import { m } from '$lib/i18n';
	import EventForm from '$lib/components/event/EventForm.svelte';
	import { formFromEvent, toUpdatePayload, type EventFormValues } from '$lib/components/event/eventForm';
	import { eventErrorMessage } from '$lib/components/event/eventState';
	import type { PageData } from './$types';

	interface Props {
		data: PageData;
	}
	let { data }: Props = $props();

	// The form is seeded once from the loaded event (edits are local until saved).
	const event = untrack(() => data.event);
	const initial = formFromEvent(event);
	let values = $state<EventFormValues>(formFromEvent(event));
	let submitting = $state(false);
	let error = $state<string | null>(null);

	async function submit(formValues: EventFormValues) {
		const payload = toUpdatePayload(event, formValues);
		if (Object.keys(payload).length === 0) {
			await goto(`/events/${event.id}`);
			return;
		}
		submitting = true;
		error = null;
		try {
			await eventsApi.updateEvent(event.id, payload);
			toast.success(m('event.toast.updated'));
			await goto(`/events/${event.id}`, { invalidateAll: true });
		} catch (err) {
			error = eventErrorMessage(err);
		} finally {
			submitting = false;
		}
	}
</script>

<svelte:head><title>{m('event.form.editTitle')} — {event.title}</title></svelte:head>

<div class="flex items-center gap-3 mb-6 mt-3">
	<button
		type="button"
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors spring-bounce"
		aria-label={m('event.detail.back')}
	>
		<span class="material-symbols-outlined text-[22px]" aria-hidden="true">arrow_back</span>
	</button>
	<h2 class="text-xl font-extrabold font-headline">{m('event.form.editTitle')}</h2>
</div>

<EventForm
	bind:values
	mode="edit"
	{error}
	{submitting}
	originalStart={{ date: initial.date, time: initial.time }}
	onSubmit={submit}
/>
