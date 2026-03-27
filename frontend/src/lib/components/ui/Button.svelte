<script lang="ts">
	interface Props {
		variant?: 'primary' | 'secondary' | 'tertiary' | 'ghost' | 'danger';
		size?: 'sm' | 'md' | 'lg';
		loading?: boolean;
		disabled?: boolean;
		type?: 'button' | 'submit' | 'reset';
		fullWidth?: boolean;
		onclick?: () => void;
		children?: import('svelte').Snippet;
	}

	let {
		variant = 'primary',
		size = 'md',
		loading = false,
		disabled = false,
		type = 'button',
		fullWidth = false,
		onclick,
		children
	}: Props = $props();

	const base =
		'inline-flex items-center justify-center gap-2 rounded-full font-headline font-bold transition-all active:scale-95 hover:scale-[1.02] disabled:opacity-50 disabled:pointer-events-none';

	const variants = {
		primary:
			'bg-gradient-to-r from-primary to-primary-container text-on-primary shadow-[0_8px_24px_rgba(137,81,0,0.20)]',
		secondary: 'bg-surface-container-high text-on-surface-variant hover:bg-surface-container-highest',
		tertiary: 'bg-tertiary-container text-on-tertiary-container border border-tertiary/10',
		ghost: 'bg-white/50 backdrop-blur-md text-on-surface-variant border border-outline-variant/30 hover:bg-white',
		danger: 'bg-error text-on-error shadow-[0_8px_24px_rgba(186,26,26,0.20)]'
	};

	const sizes = {
		sm: 'py-2 px-5 text-sm',
		md: 'py-3 px-7 text-base',
		lg: 'py-4 px-8 text-lg'
	};
</script>

<button
	{type}
	{disabled}
	aria-busy={loading}
	class="{base} {variants[variant]} {sizes[size]} {fullWidth ? 'w-full' : ''}"
	{onclick}
>
	{#if loading}
		<span class="w-4 h-4 rounded-full border-2 border-current border-t-transparent animate-spin"></span>
	{/if}
	{@render children?.()}
</button>
