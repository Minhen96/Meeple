<script lang="ts">
	import { onMount } from 'svelte';
	import { toast } from 'svelte-sonner';
	import { m, type MessageKey } from '$lib/i18n';
	import { notificationsApi } from '$lib/api/notifications';
	import { disablePush, enablePush, pushStatus, type PushStatus } from '$lib/push';
	import type { NotificationPreference, NotificationSettings } from '$lib/types';
	import {
		PREFERENCE_CATEGORIES,
		browserTimeZone,
		categoryEnabled,
		categoryUpdate,
		mergePreferences,
		type Channel,
		type PreferenceCategory
	} from './preferences';

	let loading = $state(true);
	let loadFailed = $state(false);
	let prefs = $state<NotificationPreference[]>([]);
	let settings = $state<NotificationSettings>({
		quietHoursEnabled: false,
		quietHoursStart: '22:00',
		quietHoursEnd: '08:00',
		timezone: null
	});
	let savingKey = $state<string | null>(null);
	let push = $state<PushStatus>('unconfigured');
	let pushBusy = $state(false);

	const CHANNELS: ReadonlyArray<{ key: Channel; label: MessageKey }> = [
		{ key: 'inAppEnabled', label: 'notif.prefs.inApp' },
		{ key: 'pushEnabled', label: 'notif.prefs.push' }
	];

	function categoryLabel(key: PreferenceCategory): string {
		return m(`notif.prefs.category.${key}` as MessageKey);
	}

	async function load() {
		loading = true;
		loadFailed = false;
		try {
			const [p, s] = await Promise.all([
				notificationsApi.getPreferences(),
				notificationsApi.getSettings()
			]);
			prefs = p;
			settings = {
				...s,
				quietHoursStart: s.quietHoursStart ?? '22:00',
				quietHoursEnd: s.quietHoursEnd ?? '08:00'
			};
		} catch {
			loadFailed = true;
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		push = pushStatus();
		void load();
	});

	async function toggleCategory(key: PreferenceCategory, channel: Channel) {
		const category = PREFERENCE_CATEGORIES.find((c) => c.key === key);
		if (!category || savingKey) return;
		const next = !categoryEnabled(prefs, category.types, channel);
		const previous = prefs;
		savingKey = `${key}.${channel}`;
		prefs = mergePreferences(prefs, categoryUpdate(prefs, category.types, channel, next));
		try {
			prefs = await notificationsApi.updatePreferences(
				categoryUpdate(previous, category.types, channel, next)
			);
		} catch {
			prefs = previous;
			toast.error(m('notif.prefs.saveFailed'));
		} finally {
			savingKey = null;
		}
	}

	async function saveSettings(next: NotificationSettings) {
		if (next.quietHoursEnabled && next.quietHoursStart === next.quietHoursEnd) {
			toast.error(m('notif.quiet.sameTime'));
			return;
		}
		const previous = settings;
		settings = next;
		savingKey = 'quiet';
		try {
			const saved = await notificationsApi.updateSettings({
				...next,
				// First save pins the browser's zone so quiet hours follow the user's clock
				timezone: next.timezone ?? browserTimeZone()
			});
			settings = {
				...saved,
				quietHoursStart: saved.quietHoursStart ?? next.quietHoursStart,
				quietHoursEnd: saved.quietHoursEnd ?? next.quietHoursEnd
			};
		} catch {
			settings = previous;
			toast.error(m('notif.prefs.saveFailed'));
		} finally {
			savingKey = null;
		}
	}

	function onTimeChange(field: 'quietHoursStart' | 'quietHoursEnd', value: string) {
		if (!/^\d{2}:\d{2}$/.test(value)) return;
		void saveSettings({ ...settings, [field]: value });
	}

	async function togglePush() {
		if (pushBusy) return;
		pushBusy = true;
		try {
			push = push === 'enabled' ? await disablePush() : await enablePush();
		} finally {
			pushBusy = false;
		}
	}

	const PUSH_TEXT: Record<Exclude<PushStatus, 'unconfigured'>, MessageKey> = {
		enabled: 'notif.push.enabled',
		disabled: 'notif.push.disabled',
		denied: 'notif.push.denied',
		unsupported: 'notif.push.unsupported'
	};
</script>

{#snippet toggle(on: boolean, label: string, onclick: () => void, disabled: boolean)}
	<button
		type="button"
		role="switch"
		aria-checked={on}
		aria-label={label}
		{disabled}
		{onclick}
		class="relative inline-flex h-6 w-11 flex-shrink-0 items-center rounded-full transition-colors disabled:opacity-50
			{on ? 'bg-primary-container' : 'bg-surface-container-highest'}"
	>
		<span
			class="inline-block h-5 w-5 rounded-full bg-surface-container-lowest shadow transition-transform
				{on ? 'translate-x-[22px]' : 'translate-x-0.5'}"
		></span>
	</button>
{/snippet}

<svelte:head><title>{m('notif.prefs.title')} — Meeple</title></svelte:head>

<div class="flex items-center gap-3 mb-6">
	<button
		onclick={() => history.back()}
		class="text-on-surface-variant"
		aria-label={m('notif.page.back')}
	>
		<span class="material-symbols-outlined">arrow_back</span>
	</button>
	<h2 class="text-xl font-extrabold font-headline">{m('notif.prefs.title')}</h2>
</div>

{#if loading}
	<div class="space-y-3" aria-busy="true">
		{#each Array(6) as _, i (i)}
			<div class="skeleton rounded h-10 w-full"></div>
		{/each}
	</div>
{:else if loadFailed}
	<div class="flex flex-col items-center gap-3 py-16 text-center text-on-surface-variant">
		<span class="material-symbols-outlined text-5xl opacity-40">cloud_off</span>
		<p class="font-semibold">{m('notif.prefs.loadFailed')}</p>
		<button onclick={load} class="text-sm text-primary font-label font-semibold"
			>{m('notif.list.retry')}</button
		>
	</div>
{:else}
	<p class="text-sm text-on-surface-variant mb-4">{m('notif.prefs.intro')}</p>

	<section class="bg-surface-container-low rounded-xl p-4 mb-6">
		<div class="grid grid-cols-[1fr_auto_auto] items-center gap-x-6 gap-y-4">
			<span class="text-xs font-label font-bold uppercase tracking-wider text-on-surface-variant">
				{m('notif.prefs.type')}
			</span>
			{#each CHANNELS as channel (channel.key)}
				<span
					class="text-xs font-label font-bold uppercase tracking-wider text-on-surface-variant text-center"
				>
					{m(channel.label)}
				</span>
			{/each}

			{#each PREFERENCE_CATEGORIES as category (category.key)}
				<span class="text-sm text-on-surface">{categoryLabel(category.key)}</span>
				{#each CHANNELS as channel (channel.key)}
					<div class="flex justify-center">
						{@render toggle(
							categoryEnabled(prefs, category.types, channel.key),
							m('notif.prefs.toggle', {
								category: categoryLabel(category.key),
								channel: m(channel.label)
							}),
							() => toggleCategory(category.key, channel.key),
							savingKey !== null
						)}
					</div>
				{/each}
			{/each}
		</div>
	</section>

	<section class="bg-surface-container-low rounded-xl p-4 mb-6">
		<div class="flex items-center gap-3">
			<div class="flex-1">
				<p class="font-semibold text-on-surface">{m('notif.quiet.title')}</p>
				<p class="text-xs text-on-surface-variant mt-0.5">{m('notif.quiet.description')}</p>
			</div>
			{@render toggle(
				settings.quietHoursEnabled,
				m('notif.quiet.title'),
				() => saveSettings({ ...settings, quietHoursEnabled: !settings.quietHoursEnabled }),
				savingKey !== null
			)}
		</div>
		<div class="grid grid-cols-2 gap-3 mt-4">
			<label class="flex flex-col gap-1 text-xs font-label text-on-surface-variant">
				{m('notif.quiet.start')}
				<input
					type="time"
					value={settings.quietHoursStart}
					disabled={!settings.quietHoursEnabled || savingKey !== null}
					onchange={(e) => onTimeChange('quietHoursStart', e.currentTarget.value)}
					class="rounded-xl bg-surface-container-lowest px-3 py-2 text-sm text-on-surface disabled:opacity-50"
				/>
			</label>
			<label class="flex flex-col gap-1 text-xs font-label text-on-surface-variant">
				{m('notif.quiet.end')}
				<input
					type="time"
					value={settings.quietHoursEnd}
					disabled={!settings.quietHoursEnabled || savingKey !== null}
					onchange={(e) => onTimeChange('quietHoursEnd', e.currentTarget.value)}
					class="rounded-xl bg-surface-container-lowest px-3 py-2 text-sm text-on-surface disabled:opacity-50"
				/>
			</label>
		</div>
		{#if settings.timezone}
			<p class="text-xs text-on-surface-variant mt-3">
				{m('notif.quiet.timezone', { zone: settings.timezone })}
			</p>
		{/if}
	</section>

	{#if push !== 'unconfigured'}
		<section class="bg-surface-container-low rounded-xl p-4">
			<div class="flex items-center gap-3">
				<div class="flex-1">
					<p class="font-semibold text-on-surface">{m('notif.push.title')}</p>
					<p class="text-xs text-on-surface-variant mt-0.5">{m(PUSH_TEXT[push])}</p>
				</div>
				{#if push === 'enabled' || push === 'disabled'}
					{@render toggle(push === 'enabled', m('notif.push.title'), togglePush, pushBusy)}
				{/if}
			</div>
		</section>
	{/if}
{/if}
