<script lang="ts">
	import { fade, fly } from "svelte/transition";
	import { tick, onMount } from "svelte";
	import { aiApi } from "$lib/api/ai";
	import { ApiRequestError } from "$lib/api/client";
	import type { ConversationTurn } from "$lib/types";

	interface Message {
		role: "user" | "assistant";
		content: string;
		sourceMode?: "rulebook" | "general";
		disclaimer?: string;
	}

	interface Props {
		show: boolean;
		gameId: string;
		gameTitle: string;
	}
	let { show = $bindable(), gameId, gameTitle }: Props = $props();

	const STORAGE_KEY = $derived(`ai_chat_${gameId}`);

	function makeWelcome(): Message {
		return {
			role: "assistant",
			content: `Hi! I'm ready to answer questions about **${gameTitle}**. Ask me about setup, turn order, rules, or tricky edge cases!`
		};
	}

	let messages = $state<Message[]>([makeWelcome()]);
	let inputValue = $state("");
	let isTyping = $state(false);
	let scrollContainer = $state<HTMLDivElement>();

	onMount(() => {
		const stored = localStorage.getItem(STORAGE_KEY);
		if (stored) {
			try {
				const parsed = JSON.parse(stored) as Message[];
				if (Array.isArray(parsed) && parsed.length > 0) {
					messages = parsed;
				}
			} catch {
				// ignore corrupt storage
			}
		}
	});

	$effect(() => {
		if (show) {
			tick().then(() => {
				if (scrollContainer) scrollContainer.scrollTop = scrollContainer.scrollHeight;
			});
		}
	});

	function getHistory(): ConversationTurn[] {
		const pairs: ConversationTurn[] = [];
		for (let i = 0; i < messages.length - 1; i++) {
			if (messages[i].role === "user" && messages[i + 1]?.role === "assistant") {
				pairs.push({ question: messages[i].content, answer: messages[i + 1].content });
			}
		}
		return pairs.slice(-3);
	}

	function saveToStorage() {
		try {
			localStorage.setItem(STORAGE_KEY, JSON.stringify(messages));
		} catch {
			// quota exceeded — ignore
		}
	}

	function clearChat() {
		messages = [makeWelcome()];
		localStorage.removeItem(STORAGE_KEY);
	}

	async function scrollToBottom() {
		await tick();
		if (scrollContainer) {
			scrollContainer.scrollTo({ top: scrollContainer.scrollHeight, behavior: "smooth" });
		}
	}

	async function sendMessage() {
		if (!inputValue.trim() || isTyping) return;

		const userMessage = inputValue.trim();
		inputValue = "";
		messages = [...messages, { role: "user", content: userMessage }];
		await scrollToBottom();

		isTyping = true;
		try {
			const history = getHistory();
			const res = await aiApi.askRules(gameId, userMessage, history);
			messages = [
				...messages,
				{
					role: "assistant" as const,
					content: res.answer,
					sourceMode: res.sourceMode,
					disclaimer: res.disclaimer
				}
			];
			saveToStorage();
		} catch (e) {
			let content: string;
			if (e instanceof ApiRequestError) {
				if (e.status === 429) {
					content = "You've reached the daily limit (20 questions). Come back tomorrow!";
				} else if (e.status === 400) {
					content = "Question too long — please keep it under 500 characters.";
				} else {
					content = "Something went wrong. Please try again.";
				}
			} else {
				content = "Could not reach the server. Check your connection and try again.";
			}
			messages = [...messages, { role: "assistant" as const, content }];
		} finally {
			isTyping = false;
			await scrollToBottom();
		}
	}

	function close() {
		show = false;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === "Enter") sendMessage();
	}

	// Simple inline markdown: escape HTML, then convert **bold** and *italic*
	function renderMd(text: string): string {
		const escaped = text
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;");
		return escaped
			.replace(/\*\*(.*?)\*\*/gs, "<strong>$1</strong>")
			.replace(/\*(.*?)\*/gs, "<em>$1</em>")
			.replace(/\n/g, "<br>");
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

	<!-- Drawer -->
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
						{gameTitle}
					</p>
				</div>
			</div>
			<div class="flex items-center gap-1">
				{#if messages.length > 1}
					<button
						onclick={clearChat}
						title="Clear chat"
						class="w-9 h-9 rounded-full hover:bg-surface-container-high flex items-center justify-center transition-colors text-on-surface-variant"
					>
						<span class="material-symbols-outlined text-[18px]">delete_sweep</span>
					</button>
				{/if}
				<button
					onclick={close}
					class="w-10 h-10 rounded-full hover:bg-surface-container-high flex items-center justify-center transition-colors"
				>
					<span class="material-symbols-outlined text-on-surface-variant">close</span>
				</button>
			</div>
		</div>

		<!-- Chat Content -->
		<div
			bind:this={scrollContainer}
			class="flex-1 overflow-y-auto p-4 space-y-6 bg-surface-container-lowest/30"
		>
			{#each messages as msg, i}
				<div class="flex {msg.role === 'user' ? 'justify-end' : 'justify-start'}">
					<div class="max-w-[85%] space-y-1">
						<div class="
							p-4 rounded-2xl text-sm leading-relaxed
							{msg.role === 'user'
								? 'bg-primary text-on-primary rounded-tr-none shadow-md shadow-primary/10'
								: 'bg-surface-container-low text-on-surface rounded-tl-none border border-outline-variant/10 shadow-sm'}
						">
							<!-- eslint-disable-next-line svelte/no-at-html-tags -->
							{@html renderMd(msg.content)}
						</div>

						<!-- Source mode badge — only on real assistant answers (not the welcome msg) -->
						{#if msg.role === 'assistant' && msg.sourceMode && i > 0}
							<div class="flex items-center gap-2 px-1 flex-wrap">
								<span class="inline-flex items-center gap-1 text-[9px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full
									{msg.sourceMode === 'rulebook'
										? 'bg-primary/10 text-primary'
										: 'bg-amber-400/10 text-amber-500'}">
									<span class="material-symbols-outlined text-[10px]">
										{msg.sourceMode === 'rulebook' ? 'menu_book' : 'psychology'}
									</span>
									{msg.sourceMode === 'rulebook' ? 'Rulebook' : 'General AI'}
								</span>
							</div>
							{#if msg.disclaimer}
								<p class="text-[9px] text-on-surface-variant opacity-50 px-1 leading-snug max-w-[260px]">
									{msg.disclaimer}
								</p>
							{/if}
						{/if}

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
					placeholder="Ask a rule question…"
					maxlength="500"
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
				AI can make mistakes. Verify critical rules with the official rulebook.
			</p>
		</div>
	</div>
{/if}

<style>
	.overflow-y-auto {
		scrollbar-width: none;
		-ms-overflow-style: none;
	}
	.overflow-y-auto::-webkit-scrollbar {
		display: none;
	}
</style>
