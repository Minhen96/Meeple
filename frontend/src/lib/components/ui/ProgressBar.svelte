<script lang="ts">
	/**
	 * Native <progress> styled with Tailwind — avoids inline width styles for
	 * dynamic values. Track/fill colors use design tokens only.
	 */
	type Tone = 'primary' | 'secondary' | 'tertiary' | 'muted';
	type Track = 'high' | 'highest';

	interface Props {
		value: number;
		max?: number;
		tone?: Tone;
		track?: Track;
		/** Height + width utilities, e.g. "h-2 w-full". */
		class?: string;
		label?: string;
	}

	let { value, max = 100, tone = 'primary', track = 'high', class: className = 'h-2 w-full', label }: Props =
		$props();

	const FILL: Record<Tone, string> = {
		primary: '[&::-webkit-progress-value]:bg-primary [&::-moz-progress-bar]:bg-primary',
		secondary: '[&::-webkit-progress-value]:bg-secondary [&::-moz-progress-bar]:bg-secondary',
		tertiary: '[&::-webkit-progress-value]:bg-tertiary [&::-moz-progress-bar]:bg-tertiary',
		muted: '[&::-webkit-progress-value]:bg-on-surface/20 [&::-moz-progress-bar]:bg-on-surface/20'
	};

	const TRACK: Record<Track, string> = {
		high: 'bg-surface-container-high [&::-webkit-progress-bar]:bg-surface-container-high',
		highest: 'bg-surface-container-highest [&::-webkit-progress-bar]:bg-surface-container-highest'
	};

	const clamped = $derived(Math.min(Math.max(Number.isFinite(value) ? value : 0, 0), max));
</script>

<progress
	value={clamped}
	{max}
	aria-label={label}
	class="block appearance-none overflow-hidden rounded-full [&::-webkit-progress-bar]:rounded-full [&::-webkit-progress-value]:rounded-full [&::-webkit-progress-value]:transition-all [&::-webkit-progress-value]:duration-500 [&::-moz-progress-bar]:rounded-full {TRACK[
		track
	]} {FILL[tone]} {className}"
></progress>
