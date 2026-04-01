<script lang="ts">
	import { fade, fly } from "svelte/transition";
	import { tick } from "svelte";

	interface Message {
		role: "user" | "assistant";
		content: string;
	}

	interface Props {
		show: boolean;
		gameId: string;
		gameTitle: string;
	}
	let { show = $bindable(), gameId, gameTitle }: Props = $props();

	let messages = $state<Message[]>([
		{
			role: "assistant",
			content: `Hi! I've read the rules for **${gameTitle}**. You can ask me anything about game setup, turns, or specific card effects!`
		}
	]);
	let inputValue = $state("");
	let isTyping = $state(false);
	let scrollContainer = $state<HTMLDivElement>();

	async function scrollToBottom() {
		await tick();
		if (scrollContainer) {
			scrollContainer.scrollTo({
				top: scrollContainer.scrollHeight,
				behavior: "smooth"
			});
		}
	}

	async function sendMessage() {
		if (!inputValue.trim() || isTyping) return;

		const userMessage = inputValue.trim();
		inputValue = "";
		messages.push({ role: "user", content: userMessage });
		await scrollToBottom();

		isTyping = true;
		
		// Simulate API delay
		setTimeout(async () => {
			messages.push({
				role: "assistant",
				content: `I'm still learning the deep strategy for **${gameTitle}**, but based on the rulebook, that action is allowed during the Harvest phase as long as you have enough resources. (Backend API integration coming soon!)`
			});
			isTyping = false;
			await scrollToBottom();
		}, 1000);
	}

	function close() {
		show = false;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === "Enter") {
			sendMessage();
		}
	}
</script>

{#if show}
	<!-- Backdrop -->
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		transition:fade={{ duration: 200 }}
		class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[100]"
		onclick={close}
	></div>

	<!-- Drawer / Sidebar -->
	<div
		transition:fly={{ x: 400, duration: 400, opacity: 1 }}
		class="fixed right-0 top-0 h-full w-full max-w-[420px] bg-surface border-l border-outline-variant/20 z-[101] shadow-2xl flex flex-col"
	>
		<!-- Header -->
		<div class="p-4 border-b border-outline-variant/10 flex items-center justify-between bg-surface-container-lowest">
			<div class="flex items-center gap-3">
				<div class="w-10 h-10 rounded-full bg-tertiary/10 flex items-center justify-center text-tertiary shadow-inner">
					<span class="material-symbols-outlined">smart_toy</span>
				</div>
				<div>
					<h3 class="font-bold text-on-surface leading-tight text-sm">Rules Assistant</h3>
					<p class="text-[10px] uppercase font-black tracking-widest text-on-surface-variant opacity-70">
						Context: {gameTitle}
					</p>
				</div>
			</div>
			<button
				onclick={close}
				class="w-10 h-10 rounded-full hover:bg-surface-container-high flex items-center justify-center transition-colors"
			>
				<span class="material-symbols-outlined text-on-surface-variant">close</span>
			</button>
		</div>

		<!-- Chat Content -->
		<div 
			bind:this={scrollContainer}
			class="flex-1 overflow-y-auto p-4 space-y-6 bg-surface-container-lowest/30"
		>
			{#each messages as msg}
				<div class="flex {msg.role === 'user' ? 'justify-end' : 'justify-start'}">
					<div class="max-w-[85%] space-y-1">
						<div class="
							p-4 rounded-2xl text-sm leading-relaxed
							{msg.role === 'user' 
								? 'bg-primary text-on-primary rounded-tr-none shadow-md shadow-primary/10' 
								: 'bg-surface-container-low text-on-surface rounded-tl-none border border-outline-variant/10 shadow-sm'}
						">
							{msg.content}
						</div>
						<p class="text-[10px] font-bold uppercase tracking-tighter text-on-surface-variant opacity-40 px-1">
							{msg.role === 'user' ? 'You' : 'Assistant'}
						</p>
					</div>
				</div>
			{/each}

			{#if isTyping}
				<div class="flex justify-start">
					<div class="bg-surface-container-low p-4 rounded-2xl rounded-tl-none border border-outline-variant/10 flex gap-1 items-center h-10">
						<div class="w-1.5 h-1.5 bg-on-surface-variant/40 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
						<div class="w-1.5 h-1.5 bg-on-surface-variant/40 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
						<div class="w-1.5 h-1.5 bg-on-surface-variant/40 rounded-full animate-bounce"></div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Input area -->
		<div class="p-4 bg-surface-container-lowest border-t border-outline-variant/10">
			<div class="relative flex items-center gap-2 bg-surface-container-high rounded-2xl px-4 py-2 border border-outline-variant/10 focus-within:border-primary/30 transition-all shadow-inner">
				<input
					type="text"
					bind:value={inputValue}
					onkeydown={handleKeydown}
					placeholder="Ask a rule question..."
					class="flex-1 bg-transparent border-none text-sm py-2 focus:outline-none"
				/>
				<button 
					onclick={sendMessage}
					disabled={!inputValue.trim() || isTyping}
					class="w-10 h-10 rounded-xl bg-primary text-on-primary flex items-center justify-center shadow-lg shadow-primary/20 disabled:opacity-30 disabled:shadow-none transition-all active:scale-95"
				>
					<span class="material-symbols-outlined">send</span>
				</button>
			</div>
			<p class="text-[9px] text-center text-on-surface-variant mt-3 opacity-50 font-medium">
				AI can make mistakes. Check the rulebook for competitive play.
			</p>
		</div>
	</div>
{/if}

<style>
	/* Hide scrollbar for cleaner look */
	.overflow-y-auto {
		scrollbar-width: none;
		-ms-overflow-style: none;
	}
	.overflow-y-auto::-webkit-scrollbar {
		display: none;
	}
</style>
