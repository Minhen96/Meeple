<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
</script>

<svelte:head><title>Create Event — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">Create Event</h2>

<form class="space-y-5 pb-24">
	<!-- Game -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Game</label>
		<button type="button" class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-left text-on-surface-variant text-sm">
			Search for a game...
		</button>
	</div>

	<!-- Title -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Event Title</label>
		<input type="text" placeholder="e.g. Heavy Euro Night" class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm" />
	</div>

	<!-- Date & Time -->
	<div class="grid grid-cols-2 gap-3">
		<div>
			<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Date</label>
			<input type="date" class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm" />
		</div>
		<div>
			<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Time</label>
			<input type="time" class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm" />
		</div>
	</div>

	<!-- Location -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Location</label>
		<input type="text" placeholder="Address, venue, or 'Online'" class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm" />
	</div>

	<!-- Max Players -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Max Players</label>
		<input type="number" min="2" max="50" value="8" class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm" />
	</div>

	<!-- Description -->
	<div>
		<label class="block text-xs font-label font-bold uppercase tracking-widest text-on-surface-variant mb-2">Description (optional)</label>
		<textarea rows="3" placeholder="Tell people what to expect..." class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"></textarea>
	</div>

	<!-- Submit -->
	<div class="fixed bottom-24 left-0 right-0 px-4 max-w-lg mx-auto">
		<Button type="submit" fullWidth>Create Event</Button>
	</div>
</form>
