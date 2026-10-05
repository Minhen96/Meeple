<!--
	Shared create / edit event form (SCREENS section 6.5). The parent owns submission: `onSubmit`
	gets the validated values and returns once the request finished (errors are shown by the parent).
-->
<script lang="ts">
	import { m } from '$lib/i18n';
	import type { EventVisibility } from '$lib/types';
	import FriendPicker from './FriendPicker.svelte';
	import GamePicker from './GamePicker.svelte';
	import {
		DESCRIPTION_MAX,
		LOCATION_MAX,
		MAX_PLAYERS,
		MIN_PLAYERS,
		TITLE_MAX,
		clampPlayers,
		suggestedTitle,
		toDateInput,
		validateForm,
		type EventFormValues,
		type PickedGame
	} from './eventForm';

	interface Props {
		values: EventFormValues;
		mode: 'create' | 'edit';
		/** Error from the last submit attempt (already localized). */
		error?: string | null;
		submitting?: boolean;
		/** Edit mode: skip the "in the past" check while the time is unchanged. */
		originalStart?: { date: string; time: string } | null;
		onSubmit: (values: EventFormValues) => void;
	}

	let {
		values = $bindable(),
		mode,
		error = null,
		submitting = false,
		originalStart = null,
		onSubmit
	}: Props = $props();

	let localError = $state<string | null>(null);
	const shownError = $derived(localError ?? error);
	const minDate = toDateInput(new Date());

	const visibilityOptions: { value: EventVisibility; icon: string; label: string; desc: string }[] = [
		{ value: 'PUBLIC', icon: 'public', label: m('event.visibility.public'), desc: m('event.visibility.publicDesc') },
		{ value: 'FRIENDS', icon: 'group', label: m('event.visibility.friends'), desc: m('event.visibility.friendsDesc') },
		{
			value: 'INVITE_ONLY',
			icon: 'lock',
			label: m('event.visibility.inviteOnly'),
			desc: m('event.visibility.inviteOnlyDesc')
		}
	];

	function onGameChange(game: PickedGame | null) {
		values.game = game;
		values.title = suggestedTitle(game, values.title);
	}

	function setPlayers(n: number) {
		values.maxParticipants = clampPlayers(n);
	}

	function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		const unchangedTime =
			originalStart !== null && originalStart.date === values.date && originalStart.time === values.time;
		const problem = validateForm(values, new Date(), !unchangedTime);
		localError = problem ? m(problem) : null;
		if (!problem) onSubmit(values);
	}

	const labelClass = 'block px-1 mb-2 text-[10px] font-label font-black uppercase tracking-widest text-on-surface-variant';
	const inputClass =
		'w-full bg-surface-container-highest rounded-lg px-4 py-3 text-on-surface placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary/30 focus:outline-none font-body text-sm';
</script>

<form onsubmit={handleSubmit} class="space-y-5 pb-36 max-w-2xl mx-auto" novalidate>
	{#if shownError}
		<p class="text-sm font-semibold text-on-error-container bg-error-container rounded-lg px-4 py-3" role="alert">
			{shownError}
		</p>
	{/if}

	<section class="bg-surface-container-low rounded-lg p-5 space-y-5">
		<div>
			<span class={labelClass}>{m('event.form.game')}</span>
			<GamePicker game={values.game} onChange={onGameChange} />
		</div>

		<div>
			<label for="event-title" class={labelClass}>{m('event.form.title')}</label>
			<input
				id="event-title"
				type="text"
				bind:value={values.title}
				maxlength={TITLE_MAX}
				required
				placeholder={m('event.form.titlePlaceholder')}
				class={inputClass}
			/>
		</div>

		<div class="grid grid-cols-2 gap-3">
			<div>
				<label for="event-date" class={labelClass}>{m('event.form.date')}</label>
				<input
					id="event-date"
					type="date"
					bind:value={values.date}
					min={mode === 'create' ? minDate : undefined}
					required
					class={inputClass}
				/>
			</div>
			<div>
				<label for="event-time" class={labelClass}>{m('event.form.time')}</label>
				<input id="event-time" type="time" step="1800" bind:value={values.time} required class={inputClass} />
			</div>
		</div>

		<div>
			<label for="event-location" class={labelClass}>{m('event.form.location')}</label>
			<input
				id="event-location"
				type="text"
				bind:value={values.location}
				maxlength={LOCATION_MAX}
				placeholder={m('event.form.locationPlaceholder')}
				class={inputClass}
			/>
		</div>
	</section>

	<section class="bg-surface-container-low rounded-lg p-5 space-y-5">
		<div>
			<div class="flex items-center justify-between mb-2">
				<span class={labelClass}>{m('event.form.maxPlayers')}</span>
				<span class="px-3 py-1 bg-secondary/10 text-secondary rounded-full text-xs font-black font-headline">
					{m('event.form.playersCount', { count: values.maxParticipants })}
				</span>
			</div>
			<div class="flex items-center gap-4">
				<button
					type="button"
					onclick={() => setPlayers(values.maxParticipants - 1)}
					disabled={values.maxParticipants <= MIN_PLAYERS}
					class="w-10 h-10 rounded-lg bg-surface-container-high flex items-center justify-center hover:bg-primary/20 transition-colors disabled:opacity-40 spring-bounce"
					aria-label={m('event.form.decrease')}
				>
					<span class="material-symbols-outlined" aria-hidden="true">remove</span>
				</button>
				<input
					type="range"
					min={MIN_PLAYERS}
					max={MAX_PLAYERS}
					value={values.maxParticipants}
					oninput={(e) => setPlayers(Number(e.currentTarget.value))}
					aria-label={m('event.form.maxPlayers')}
					class="flex-1 accent-primary"
				/>
				<button
					type="button"
					onclick={() => setPlayers(values.maxParticipants + 1)}
					disabled={values.maxParticipants >= MAX_PLAYERS}
					class="w-10 h-10 rounded-lg bg-surface-container-high flex items-center justify-center hover:bg-primary/20 transition-colors disabled:opacity-40 spring-bounce"
					aria-label={m('event.form.increase')}
				>
					<span class="material-symbols-outlined" aria-hidden="true">add</span>
				</button>
			</div>
		</div>

		<fieldset>
			<legend class={labelClass}>{m('event.form.visibility')}</legend>
			<div class="grid grid-cols-1 gap-2">
				{#each visibilityOptions as opt (opt.value)}
					{@const active = values.visibility === opt.value}
					<button
						type="button"
						onclick={() => (values.visibility = opt.value)}
						aria-pressed={active}
						class="flex items-center gap-4 p-3 rounded-lg text-left transition-all spring-bounce
							{active ? 'bg-primary/10 ring-2 ring-primary' : 'bg-surface-container hover:bg-surface-container-high'}"
					>
						<span
							class="w-10 h-10 rounded-lg flex items-center justify-center
								{active ? 'bg-primary text-on-primary' : 'bg-surface-container-highest text-on-surface-variant'}"
						>
							<span class="material-symbols-outlined text-[20px]" aria-hidden="true">{opt.icon}</span>
						</span>
						<span class="flex-1">
							<span class="block text-sm font-bold {active ? 'text-primary' : 'text-on-surface'}">{opt.label}</span>
							<span class="block text-[11px] text-on-surface-variant">{opt.desc}</span>
						</span>
					</button>
				{/each}
			</div>
		</fieldset>

		{#if values.visibility === 'PUBLIC'}
			<div>
				<label for="event-location-display" class={labelClass}>{m('event.form.locationDisplay')}</label>
				<input
					id="event-location-display"
					type="text"
					bind:value={values.locationDisplay}
					maxlength={LOCATION_MAX}
					placeholder={m('event.form.locationDisplayPlaceholder')}
					class={inputClass}
				/>
				<p class="mt-1 px-1 text-[11px] text-on-surface-variant">{m('event.form.locationDisplayHint')}</p>
			</div>
		{/if}
	</section>

	{#if mode === 'create'}
		<section class="bg-surface-container-low rounded-lg p-5">
			<span class={labelClass}>{m('event.form.invite')}</span>
			<FriendPicker
				bind:selected={values.invitedUserIds}
				onLoaded={(friends) => {
					// Pre-selected ids (e.g. from a match) that are not friends cannot be invited
					const ids = new Set(friends.map((f) => f.id));
					values.invitedUserIds = values.invitedUserIds.filter((id) => ids.has(id));
				}}
			/>
		</section>
	{/if}

	<section class="bg-surface-container-low rounded-lg p-5">
		<label for="event-description" class={labelClass}>{m('event.form.description')}</label>
		<textarea
			id="event-description"
			bind:value={values.description}
			rows="4"
			maxlength={DESCRIPTION_MAX}
			placeholder={m('event.form.descriptionPlaceholder')}
			class="{inputClass} resize-none"
		></textarea>
		<p class="mt-1 px-1 text-right text-[11px] text-on-surface-variant">
			{m('event.form.charCount', { count: values.description.length, max: DESCRIPTION_MAX })}
		</p>
	</section>

	<div class="fixed bottom-20 left-0 right-0 z-30 px-4 py-3 bg-surface/80 backdrop-blur-xl">
		<button
			type="submit"
			disabled={submitting}
			class="max-w-2xl mx-auto w-full py-4 bg-gradient-to-r from-primary to-primary-container text-on-primary rounded-full font-headline font-bold text-base shadow-lg hover:scale-[1.02] active:scale-95 transition-all disabled:opacity-50 flex items-center justify-center gap-2"
		>
			{#if mode === 'create'}
				{submitting ? m('event.form.submitting') : m('event.form.submit')}
			{:else}
				{submitting ? m('event.form.saving') : m('event.form.save')}
			{/if}
		</button>
	</div>
</form>
