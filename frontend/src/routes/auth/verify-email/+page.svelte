<script lang="ts">
	import Button from '$lib/components/ui/Button.svelte';
</script>

<svelte:head><title>Verify Email — Meeple & Hearth</title></svelte:head>

<div class="text-center space-y-4">
	<span class="material-symbols-outlined text-6xl text-tertiary">mark_email_unread</span>
	<h2 class="text-2xl font-extrabold font-headline">Check your inbox</h2>
	<p class="text-on-surface-variant text-sm">We sent a verification link to your email address.</p>
	<Button variant="secondary" fullWidth>Resend email</Button>
	<a href="/auth/login" class="block text-sm text-primary font-semibold">Back to login</a>
</div>
