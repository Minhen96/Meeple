<script lang="ts">
	interface Props {
		class?: string;
		rounded?: boolean;
	}

	let { class: className = '', rounded = false }: Props = $props();
</script>

<div class="skeleton {rounded ? 'rounded-full' : 'rounded'} {className}"></div>
