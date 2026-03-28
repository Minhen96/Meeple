<script lang="ts">
	interface Props {
		children?: import('svelte').Snippet;
	}
	let { children }: Props = $props();
</script>

<!-- Auth screens: no AppBar or BottomNav -->
<div class="min-h-screen bg-background flex items-center justify-center px-4 py-12">
	<div class="w-full max-w-sm">
		{@render children?.()}
	</div>
</div>
