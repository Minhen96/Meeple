<script lang="ts">
	import { m } from '$lib/i18n';

	interface Props {
		/** Tailwind size + color classes, e.g. "w-5 h-5 text-primary". Stroke uses currentColor. */
		className?: string;
		label?: string;
	}

	let { className = 'w-5 h-5', label = m('common.loading') }: Props = $props();
</script>

<svg
	class="animate-spin {className}"
	viewBox="0 0 24 24"
	fill="none"
	role="status"
	aria-label={label}
>
	<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" class="opacity-20" />
	<path
		d="M22 12a10 10 0 0 0-10-10"
		stroke="currentColor"
		stroke-width="3"
		stroke-linecap="round"
	/>
</svg>
