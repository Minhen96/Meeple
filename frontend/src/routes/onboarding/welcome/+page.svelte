<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
</script>

<svelte:head><title>Welcome — Meeple & Hearth</title></svelte:head>

<div class="flex flex-col items-center text-center py-12 space-y-8">
	<div>
		<h1 class="text-4xl font-extrabold tracking-tight font-headline text-primary">Meeple & Hearth</h1>
		<p class="mt-3 text-on-surface-variant">Track your games. Organize game nights. Build memories.</p>
	</div>

	<div class="w-full space-y-4 text-left">
		{#each [
			{ icon: 'library_books', title: 'Game Library', desc: 'Browse and track every board game you own.' },
			{ icon: 'event', title: 'Game Nights', desc: 'Organize and join events with friends.' },
			{ icon: 'groups', title: 'Find Players', desc: 'Match with people who want to play the same games.' }
		] as feature}
			<div class="flex items-start gap-4 bg-surface-container-low rounded-xl p-4">
				<span class="material-symbols-outlined text-primary text-2xl mt-0.5">{feature.icon}</span>
				<div>
					<p class="font-semibold text-on-surface">{feature.title}</p>
					<p class="text-sm text-on-surface-variant">{feature.desc}</p>
				</div>
			</div>
		{/each}
	</div>

	<Button fullWidth onclick={() => history.pushState({}, '', '/onboarding/profile')}>
		Get Started
	</Button>
</div>
