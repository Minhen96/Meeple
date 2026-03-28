<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
</script>

<svelte:head><title>Create Post — Meeple & Hearth</title></svelte:head>

<h2 class="text-2xl font-extrabold font-headline mb-6">New Post</h2>

<form class="space-y-5 pb-24">
	<!-- Image picker -->
	<div class="border-2 border-dashed border-outline-variant/30 rounded-xl p-8 flex flex-col items-center gap-3 text-on-surface-variant">
		<span class="material-symbols-outlined text-4xl">add_photo_alternate</span>
		<p class="text-sm">Add photos</p>
		<input type="file" accept="image/*" multiple class="hidden" />
	</div>

	<!-- Caption -->
	<textarea
		rows="4"
		placeholder="Write a caption..."
		class="w-full bg-surface-container-highest rounded-xl px-4 py-3 text-on-surface placeholder:text-on-surface-variant focus:ring-2 focus:ring-primary/20 focus:outline-none font-body text-sm resize-none"
	></textarea>

	<!-- Game tag -->
	<button type="button" class="flex items-center gap-2 text-sm text-on-surface-variant">
		<span class="material-symbols-outlined text-[18px]">sports_esports</span>
		Tag a game
	</button>

	<!-- Submit -->
	<div class="fixed bottom-24 left-0 right-0 px-4 max-w-lg mx-auto">
		<Button type="submit" fullWidth>Post</Button>
	</div>
</form>
