<script lang="ts">
	import { eventsApi, type CreateEventPayload } from '$lib/api/events';
	import { ApiRequestError } from '$lib/api/client';
	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { fade, fly } from 'svelte/transition';

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
		{ value: 'PUBLIC',       label: 'Public',      icon: 'public',      desc: 'Anyone can see & join' },
		{ value: 'FRIENDS',      label: 'Friends',     icon: 'group',       desc: 'Only mutuals can see' },
		{ value: 'INVITE_ONLY',  label: 'Invite Only', icon: 'lock',        desc: 'Direct invites only' }
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
			await eventsApi.createEvent(payload);
			toast.success('Event created!');
			goto('/events');
		} catch (err) {
			error = err instanceof ApiRequestError ? err.message : 'Something went wrong. Please try again.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head><title>Create Event — Meeple</title></svelte:head>

<div class="relative min-h-screen overflow-x-hidden">
	<!-- Decorative Background -->
	<div class="absolute -top-24 -right-24 w-64 h-64 bg-primary/10 rounded-full blur-3xl -z-10 animate-pulse"></div>
	<div class="absolute top-1/3 -left-32 w-80 h-80 bg-secondary/10 rounded-full blur-3xl -z-10 transition-all duration-1000"></div>

	<!-- Header -->
	<div class="flex items-center gap-3 mb-8 mt-4 px-4 sticky top-4 z-20">
		<button
			onclick={() => history.back()}
			class="w-11 h-11 rounded-2xl bg-surface-container-low/80 backdrop-blur-md border border-outline-variant/30 flex items-center justify-center text-on-surface hover:bg-surface-container-high transition-all active:scale-90 shadow-sm"
			aria-label="Back"
		>
			<span class="material-symbols-outlined text-[24px]">arrow_back</span>
		</button>
		<div class="flex-1">
			<h2 class="text-2xl font-black font-headline tracking-tight text-on-surface">New Event</h2>
			<p class="text-[11px] font-label font-bold text-on-surface-variant/60 uppercase tracking-widest">Gather your party</p>
		</div>
	</div>

	<form onsubmit={handleSubmit} class="px-4 space-y-6 pb-32 max-w-2xl mx-auto" in:fade={{ duration: 300 }}>
		{#if error}
			<div class="text-xs font-semibold text-error bg-error-container/30 border border-error/20 rounded-2xl px-4 py-3 animate-in fade-in slide-in-from-top-2">
				{error}
			</div>
		{/if}

		<!-- Main Card -->
		<div class="bg-surface-container-low rounded-[2rem] p-6 shadow-sm border border-outline-variant/20 space-y-6">
			<!-- Title -->
			<div class="space-y-2">
				<label for="title" class="px-1 text-[10px] font-label font-black uppercase tracking-[0.15em] text-on-surface-variant/70">
					Event Mission
				</label>
				<input
					id="title"
					type="text"
					bind:value={title}
					placeholder="e.g. Epic Twilight Imperium"
					required
					class="w-full bg-surface-container-highest/50 border border-outline-variant/30 rounded-2xl px-5 py-4 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-4 focus:ring-primary/10 focus:border-primary/40 focus:outline-none font-body text-base transition-all"
				/>
			</div>

			<!-- Date & Time Bento -->
			<div class="grid grid-cols-2 gap-4">
				<div class="bg-surface-container-high/40 rounded-2xl p-4 border border-outline-variant/20 space-y-3 transition-colors hover:bg-surface-container-high/60 group">
					<div class="flex items-center justify-between">
						<label for="eventDate" class="text-[9px] font-label font-black uppercase tracking-widest text-on-surface-variant/80">Date</label>
						<span class="material-symbols-outlined text-primary text-[20px] opacity-70 group-hover:scale-110 transition-transform">calendar_today</span>
					</div>
					<input
						id="eventDate"
						type="date"
						bind:value={date}
						required
						min={new Date().toISOString().slice(0, 10)}
						class="w-full bg-transparent text-on-surface font-headline font-extrabold text-sm focus:outline-none accent-primary"
					/>
				</div>
				<div class="bg-surface-container-high/40 rounded-2xl p-4 border border-outline-variant/20 space-y-3 transition-colors hover:bg-surface-container-high/60 group">
					<div class="flex items-center justify-between">
						<label for="eventTime" class="text-[9px] font-label font-black uppercase tracking-widest text-on-surface-variant/80">Time</label>
						<span class="material-symbols-outlined text-secondary text-[20px] opacity-70 group-hover:scale-110 transition-transform">schedule</span>
					</div>
					<input
						id="eventTime"
						type="time"
						bind:value={time}
						required
						class="w-full bg-transparent text-on-surface font-headline font-extrabold text-sm focus:outline-none accent-secondary"
					/>
				</div>
			</div>

			<!-- Location -->
			<div class="relative group">
				<div class="absolute left-4 top-1/2 -translate-y-1/2 text-primary/70 group-focus-within:text-primary transition-colors">
					<span class="material-symbols-outlined text-[22px]">location_on</span>
				</div>
				<input
					type="text"
					bind:value={location}
					placeholder="Venue or Online address"
					class="w-full bg-surface-container-high/40 border border-outline-variant/20 rounded-2xl pl-12 pr-5 py-4 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-4 focus:ring-primary/10 focus:border-primary/40 focus:outline-none font-body text-sm transition-all"
				/>
			</div>
		</div>

		<!-- Player & Visibility Card -->
		<div class="bg-surface-container-low rounded-[2rem] p-6 shadow-sm border border-outline-variant/20 space-y-6">
			<!-- Max players slider/stepper mix -->
			<div class="space-y-4">
				<div class="flex items-center justify-between px-1">
					<label for="maxParticipants" class="text-[10px] font-label font-black uppercase tracking-widest text-on-surface-variant/70">
						Player Capacity
					</label>
					<span class="px-3 py-1 bg-secondary/10 text-secondary rounded-full text-xs font-black font-headline">
						{maxParticipants} Players
					</span>
				</div>
				<div class="flex items-center gap-4">
					<button 
						type="button"
						onclick={() => maxParticipants = Math.max(2, maxParticipants - 1)}
						class="w-10 h-10 rounded-xl bg-surface-container-high flex items-center justify-center hover:bg-primary/20 transition-colors"
					>
						<span class="material-symbols-outlined">remove</span>
					</button>
					<input
						id="maxParticipants"
						type="range"
						bind:value={maxParticipants}
						min="2"
						max="50"
						class="flex-1 accent-primary h-1.5 bg-surface-container-highest rounded-full appearance-none transition-all"
					/>
					<button 
						type="button"
						onclick={() => maxParticipants = Math.min(50, maxParticipants + 1)}
						class="w-10 h-10 rounded-xl bg-surface-container-high flex items-center justify-center hover:bg-primary/20 transition-colors"
					>
						<span class="material-symbols-outlined">add</span>
					</button>
				</div>
			</div>

			<hr class="border-outline-variant/10" />

			<!-- Visibility -->
			<div class="space-y-4">
				<p class="px-1 text-[10px] font-label font-black uppercase tracking-widest text-on-surface-variant/70">
					Visibility Setup
				</p>
				<div class="grid grid-cols-1 gap-3">
					{#each visibilityOptions as opt}
						<button
							type="button"
							onclick={() => (visibility = opt.value)}
							class="flex items-center gap-4 p-4 rounded-2xl text-left border-2 transition-all
								{visibility === opt.value
									? 'bg-primary/5 border-primary shadow-sm'
									: 'bg-surface-container border-transparent grayscale-[0.6] opacity-60 hover:opacity-100 hover:grayscale-0'}"
						>
							<div class="w-10 h-10 rounded-xl flex items-center justify-center
								{visibility === opt.value ? 'bg-primary text-on-primary' : 'bg-surface-container-highest text-on-surface-variant'}">
								<span class="material-symbols-outlined text-[20px]">{opt.icon}</span>
							</div>
							<div class="flex-1">
								<p class="text-sm font-bold {visibility === opt.value ? 'text-primary' : 'text-on-surface'}">{opt.label}</p>
								<p class="text-[11px] opacity-60">{opt.desc}</p>
							</div>
							{#if visibility === opt.value}
								<span class="material-symbols-outlined text-primary text-[20px]" in:fade>check_circle</span>
							{/if}
						</button>
					{:else}
						<!-- Added fallback for accessibility linter even if static -->
					{/each}
				</div>
			</div>
		</div>

		<!-- Description Card -->
		<div class="bg-surface-container-low rounded-[2rem] p-6 shadow-sm border border-outline-variant/20">
			<label for="description" class="px-1 block text-[10px] font-label font-black uppercase tracking-widest text-on-surface-variant/70 mb-3">
				Briefing / Notes
			</label>
			<textarea
				id="description"
				bind:value={description}
				rows="4"
				placeholder="Rules, food plan, or what to bring..."
				class="w-full bg-surface-container-high/40 border border-outline-variant/20 rounded-2xl px-5 py-4 text-on-surface placeholder:text-on-surface-variant/40 focus:ring-4 focus:ring-primary/10 focus:border-primary/40 focus:outline-none font-body text-sm resize-none transition-all"
			></textarea>
		</div>

		<!-- Bottom Action -->
		<div class="mt-8">
			<button
				type="submit"
				disabled={loading}
				class="w-full py-4.5 bg-on-surface text-surface rounded-3xl font-headline font-black text-base shadow-xl hover:scale-[1.01] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-3 overflow-hidden relative group"
			>
				<div class="absolute inset-0 bg-gradient-to-r from-primary to-secondary opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
				<span class="material-symbols-outlined text-[20px] relative z-10 group-hover:animate-bounce">rocket_launch</span>
				<span class="relative z-10">{loading ? 'Manifesting…' : 'Finalize Event'}</span>
			</button>
		</div>
	</form>
</div>

<style>
	input[type="range"]::-webkit-slider-thumb {
		-webkit-appearance: none;
		height: 24px;
		width: 24px;
		border-radius: 8px;
		background: #fff;
		border: 4px solid var(--md-sys-color-primary);
		cursor: pointer;
		box-shadow: 0 4px 10px rgba(0,0,0,0.1);
	}
	
	/* Immersive date/time fixes */
	input[type="date"]::-webkit-calendar-picker-indicator,
	input[type="time"]::-webkit-calendar-picker-indicator {
		filter: invert(var(--calendar-invert, 0%)) brightness(var(--calendar-bright, 100%));
		cursor: pointer;
	}
</style>

