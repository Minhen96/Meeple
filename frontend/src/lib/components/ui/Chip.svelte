<script lang="ts">
	interface Props {
		variant?: 'primary' | 'secondary' | 'tertiary' | 'surface';
		children?: import('svelte').Snippet;
	}

	let { variant = 'surface', children }: Props = $props();

	const variants = {
		primary: 'bg-primary-fixed text-on-primary-fixed',
		secondary: 'bg-secondary-container text-on-secondary-container',
		tertiary: 'bg-tertiary-container text-on-tertiary-container',
		surface: 'bg-surface-container-highest text-on-surface-variant'
	};
</script>

<span class="inline-block px-3 py-1 rounded-full text-xs font-bold font-label {variants[variant]}">
	{@render children?.()}
</span>
