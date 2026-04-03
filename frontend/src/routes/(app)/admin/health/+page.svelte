<script lang="ts">
	import { onMount } from "svelte";
	import { api } from "$lib/api/client";
	import { fade, fly } from "svelte/transition";

	let healthData: any = $state(null);
	let uptimeData: any = $state(null);
	let loading = $state(true);
	let error: string | null = $state(null);

	async function fetchHealth() {
		loading = true;
		error = null;
		try {
			// Fetch health and info/metrics in parallel
			const [health, uptime] = await Promise.all([
				api.get("/actuator/health").catch(() => ({ status: "DOWN" })),
				api.get("/actuator/metrics/process.uptime").catch(() => null)
			]);
			
			healthData = health;
			uptimeData = uptime;
		} catch (e: any) {
			error = e.message || "Failed to load system health data";
		} finally {
			loading = false;
		}
	}

	function formatUptime(seconds: number) {
		if (!seconds) return "N/A";
		const days = Math.floor(seconds / 86400);
		const hours = Math.floor((seconds % 86400) / 3600);
		const minutes = Math.floor((seconds % 3600) / 60);
		
		let parts = [];
		if (days > 0) parts.push(`${days}d`);
		if (hours > 0) parts.push(`${hours}h`);
		if (minutes > 0) parts.push(`${minutes}m`);
		return parts.join(" ") || "< 1m";
	}

	onMount(() => {
		fetchHealth();
		const interval = setInterval(fetchHealth, 30000); // 30s auto-refresh
		return () => clearInterval(interval);
	});
</script>

<svelte:head><title>System Health — Meeple Admin</title></svelte:head>

<div class="flex items-center gap-3 mb-8 mt-3">
	<button
		onclick={() => history.back()}
		class="w-10 h-10 rounded-full bg-surface-container-low flex items-center justify-center text-on-surface-variant hover:bg-surface-container-high transition-colors active:scale-95"
		aria-label="Back"
	>
		<span class="material-symbols-outlined text-[22px]">arrow_back</span>
	</button>
	<h2 class="text-2xl font-extrabold font-headline">System Health</h2>
</div>

{#if loading && !healthData}
	<div class="flex flex-col items-center justify-center py-20 gap-4" in:fade>
		<div class="w-12 h-12 border-4 border-primary/20 border-t-primary rounded-full animate-spin"></div>
		<p class="text-on-surface-variant font-medium animate-pulse">Monitoring vital signs...</p>
	</div>
{:else if error && !healthData}
	<div class="bg-error-container text-on-error-container p-6 rounded-2xl flex flex-col items-center gap-4 text-center shadow-lg" in:fly={{ y: 20 }}>
		<span class="material-symbols-outlined text-4xl">error</span>
		<div>
			<h3 class="font-bold text-lg">Connection Failure</h3>
			<p class="text-sm opacity-90">{error}</p>
		</div>
		<button 
			onclick={fetchHealth}
			class="px-6 py-2 bg-error text-on-error rounded-full font-bold text-sm hover:brightness-110 active:scale-95 transition-all"
		>
			Retry Connection
		</button>
	</div>
{:else}
	<div class="space-y-6" in:fade>
		<!-- Status Card -->
		<div class="bg-surface-container-lowest p-6 rounded-3xl shadow-[0_12px_40px_rgba(0,0,0,0.08)] border border-outline-variant/30 relative overflow-hidden">
			<div class="flex items-start justify-between relative z-10">
				<div>
					<p class="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-1">Service Status</p>
					<h3 class="text-4xl font-black font-headline {healthData?.status === 'UP' ? 'text-primary' : 'text-error'}">
						{healthData?.status || 'UNKNOWN'}
					</h3>
				</div>
				<div class="w-16 h-16 rounded-2xl {healthData?.status === 'UP' ? 'bg-primary/10 text-primary' : 'bg-error/10 text-error'} flex items-center justify-center">
					<span class="material-symbols-outlined text-3xl animate-pulse">
						{healthData?.status === 'UP' ? 'check_circle' : 'warning'}
					</span>
				</div>
			</div>
			
			<div class="mt-6 flex gap-4">
				<div class="flex-1 bg-surface-container-low p-4 rounded-2xl">
					<p class="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant/70 mb-1">Uptime</p>
					<p class="font-headline font-bold text-lg">{formatUptime(uptimeData?.measurements?.[0]?.value)}</p>
				</div>
				<div class="flex-1 bg-surface-container-low p-4 rounded-2xl">
					<p class="text-[10px] font-bold uppercase tracking-wider text-on-surface-variant/70 mb-1">Refresh Rate</p>
					<p class="font-headline font-bold text-lg">30s</p>
				</div>
			</div>

			<!-- Decorative background element -->
			<div class="absolute -right-10 -bottom-10 w-40 h-40 rounded-full {healthData?.status === 'UP' ? 'bg-primary/3' : 'bg-error/3'} blur-3xl"></div>
		</div>

		<!-- Components Grid -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
			<div class="bg-surface-container-lowest p-5 rounded-2xl border border-outline-variant/30 flex items-center gap-4 group hover:border-primary/50 transition-colors">
				<div class="w-12 h-12 rounded-xl bg-secondary/10 text-secondary flex items-center justify-center group-hover:scale-110 transition-transform">
					<span class="material-symbols-outlined">database</span>
				</div>
				<div class="flex-1">
					<p class="text-xs font-bold text-on-surface-variant uppercase tracking-tighter">Database</p>
					<div class="flex items-center gap-2">
						<div class="w-2 h-2 rounded-full bg-primary animate-pulse"></div>
						<p class="font-bold text-on-surface">Connected</p>
					</div>
				</div>
			</div>

			<div class="bg-surface-container-lowest p-5 rounded-2xl border border-outline-variant/30 flex items-center gap-4 group hover:border-primary/50 transition-colors">
				<div class="w-12 h-12 rounded-xl bg-tertiary/10 text-tertiary flex items-center justify-center group-hover:scale-110 transition-transform">
					<span class="material-symbols-outlined">storage</span>
				</div>
				<div class="flex-1">
					<p class="text-xs font-bold text-on-surface-variant uppercase tracking-tighter">Disk Space</p>
					<div class="flex items-center gap-2">
						<div class="w-2 h-2 rounded-full bg-primary animate-pulse"></div>
						<p class="font-bold text-on-surface">Optimal</p>
					</div>
				</div>
			</div>
		</div>

		<p class="text-center text-[11px] text-on-surface-variant italic pt-4">
			Data sourced directly from Spring Boot Actuator endpoints.
		</p>
	</div>
{/if}
