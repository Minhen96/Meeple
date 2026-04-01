<script lang="ts">
	interface Section {
		title: string;
		content: string;
		icon: string;
	}

	interface Props {
		gameId: string;
		onOpenAssistant: () => void;
	}
	let { gameId, onOpenAssistant }: Props = $props();

	// Mock data for now - will be fetched from API later
	const sections: Section[] = [
		{
			title: "Game Setup",
			icon: "grid_view",
			content: "Place the game board in the center. Each player chooses a color and takes the corresponding components. Shuffle the action cards and deal 3 to each player..."
		},
		{
			title: "Player Turn",
			icon: "play_circle",
			content: "On your turn, you must perform two different actions from the following list: Move your meeple, Harvest resources, or Construct a building..."
		},
		{
			title: "Scoring & Game End",
			icon: "military_tech",
			content: "The game ends when the last building is constructed. Players then tally their victory points from buildings, resources, and secret objectives..."
		}
	];
</script>

<div class="py-4 space-y-8 pb-12">
	<!-- Hero Header -->
	<div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-primary/10 via-background to-secondary/5 border border-outline-variant/10 p-6">
		<div class="relative z-10 flex items-start justify-between">
			<div class="space-y-1">
				<div class="flex items-center gap-2 text-primary font-black uppercase tracking-widest text-[10px]">
					<span class="material-symbols-outlined text-[16px]">auto_awesome</span>
					AI Rule Extraction
				</div>
				<h2 class="text-xl font-extrabold text-on-surface">How to Play</h2>
				<p class="text-xs text-on-surface-variant max-w-[240px] leading-relaxed">
					Follow these essential rules to get the game started quickly.
				</p>
			</div>
			<div class="w-16 h-16 rounded-2xl bg-surface-container-high flex items-center justify-center text-primary/40 rotate-12">
				<span class="material-symbols-outlined text-[40px]">menu_book</span>
			</div>
		</div>
		<!-- Abstract background shapes -->
		<div class="absolute -right-4 -bottom-4 w-32 h-32 bg-primary/5 rounded-full blur-3xl"></div>
	</div>

	<!-- Rule Sections -->
	<div class="space-y-6">
		{#each sections as section}
			<section class="group">
				<div class="flex items-center gap-3 mb-3">
					<div class="w-10 h-10 rounded-xl bg-surface-container-high flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-on-primary transition-all duration-300">
						<span class="material-symbols-outlined text-[20px]">{section.icon}</span>
					</div>
					<h3 class="font-bold text-on-surface tracking-tight">{section.title}</h3>
				</div>
				<div class="pl-13">
					<div class="bg-surface-container-low/50 rounded-2xl p-4 border border-outline-variant/5 text-sm text-on-surface-variant leading-relaxed">
						{section.content}
					</div>
				</div>
			</section>
		{/each}
	</div>

	<!-- AI Assistant Call-to-action -->
	<button 
		onclick={onOpenAssistant}
		class="w-full bg-tertiary-container/30 rounded-3xl p-6 border border-tertiary/10 flex flex-col items-center text-center gap-3 mt-4 hover:bg-tertiary-container/40 transition-colors"
	>
		<div class="w-12 h-12 rounded-full bg-tertiary/10 flex items-center justify-center text-tertiary">
			<span class="material-symbols-outlined">smart_toy</span>
		</div>
		<div class="space-y-1">
			<h4 class="font-bold text-on-tertiary-container">Still have questions?</h4>
			<p class="text-[11px] text-on-tertiary-container/70 leading-relaxed px-4">
				Our AI Assistant has read the full {gameId} rulebook and can answer specific edge cases.
			</p>
		</div>
	</button>
</div>

<style>
	.pl-13 {
		padding-left: 3.25rem;
	}
</style>
