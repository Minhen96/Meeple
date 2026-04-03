<script lang="ts">
	interface Props {
		src?: string | null;
		name?: string;
		size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | 'none';
		className?: string;
	}

	let { src = null, name = '', size = 'md', className = '' }: Props = $props();
	let imageError = $state(false);

	const sizes = {
		xs: 'w-6 h-6 text-[8px]',
		sm: 'w-8 h-8 text-[10px]',
		md: 'w-10 h-10 text-sm',
		lg: 'w-12 h-12 text-base',
		xl: 'w-16 h-16 text-lg',
		none: ''
	};

	const initials = $derived(
		name
			.split(' ')
			.slice(0, 2)
			.map((w) => w[0]?.toUpperCase() ?? '')
			.join('')
	);

	// Reset error state if src changes
	$effect(() => {
		if (src) imageError = false;
	});
</script>

<div
	class="rounded-full overflow-hidden bg-primary-fixed flex items-center justify-center flex-shrink-0 {sizes[size]} {className}"
>
	{#if src && !imageError}
		<img
			{src}
			alt={name}
			class="w-full h-full object-cover"
			onerror={() => {
				imageError = true;
			}}
		/>
	{:else}
		<span class="font-label font-bold text-on-primary-fixed">{initials || '?'}</span>
	{/if}
</div>
