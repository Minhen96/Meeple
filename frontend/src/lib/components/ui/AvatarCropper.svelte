<script lang="ts">
	// 1:1 avatar crop (SCREENS_AND_STATES section 3.3), entirely client-side: the preview is drawn
	// on a canvas (drag to move, slider to zoom) and the result is exported as WebP (JPEG where
	// WebP encoding is unavailable) at most 512px square.
	import { onMount } from 'svelte';
	import BottomSheet from './BottomSheet.svelte';
	import Button from './Button.svelte';
	import { m } from '$lib/i18n';
	import {
		AVATAR_OUTPUT_SIZE,
		MAX_ZOOM,
		MIN_ZOOM,
		clampOffset,
		cropRect,
		outputSize,
		type Point
	} from './avatarCrop';

	interface Props {
		file: File;
		onCancel: () => void;
		onCropped: (file: File) => void;
	}

	let { file, onCancel, onCropped }: Props = $props();

	const VIEWPORT = 256;
	let canvas = $state<HTMLCanvasElement | undefined>();
	let image: HTMLImageElement | null = $state(null);
	let zoom = $state(1);
	let offset: Point = $state({ x: 0, y: 0 });
	let dragStart: { pointer: Point; offset: Point } | null = null;
	let failed = $state(false);
	let working = $state(false);

	onMount(() => {
		const url = URL.createObjectURL(file);
		const img = new Image();
		img.onload = () => (image = img);
		img.onerror = () => (failed = true);
		img.src = url;
		return () => URL.revokeObjectURL(url);
	});

	function size() {
		return { width: image?.naturalWidth ?? 0, height: image?.naturalHeight ?? 0 };
	}

	$effect(() => {
		if (!image || !canvas) return;
		const ctx = canvas.getContext('2d');
		if (!ctx) return;
		const crop = cropRect(size(), VIEWPORT, zoom, offset);
		const scale = window.devicePixelRatio || 1;
		canvas.width = VIEWPORT * scale;
		canvas.height = VIEWPORT * scale;
		ctx.clearRect(0, 0, canvas.width, canvas.height);
		ctx.drawImage(image, crop.sx, crop.sy, crop.size, crop.size, 0, 0, canvas.width, canvas.height);
	});

	function onPointerDown(event: PointerEvent) {
		canvas?.setPointerCapture(event.pointerId);
		dragStart = { pointer: { x: event.clientX, y: event.clientY }, offset };
	}

	function onPointerMove(event: PointerEvent) {
		if (!dragStart) return;
		offset = clampOffset(
			{
				x: dragStart.offset.x + event.clientX - dragStart.pointer.x,
				y: dragStart.offset.y + event.clientY - dragStart.pointer.y
			},
			size(),
			VIEWPORT,
			zoom
		);
	}

	function onZoom(event: Event) {
		zoom = Number((event.currentTarget as HTMLInputElement).value);
		offset = clampOffset(offset, size(), VIEWPORT, zoom);
	}

	function toBlob(target: HTMLCanvasElement, type: string): Promise<Blob | null> {
		return new Promise((resolve) => target.toBlob(resolve, type, 0.9));
	}

	async function confirm() {
		if (!image) return;
		working = true;
		try {
			const crop = cropRect(size(), VIEWPORT, zoom, offset);
			const edge = outputSize(crop, AVATAR_OUTPUT_SIZE);
			const out = document.createElement('canvas');
			out.width = edge;
			out.height = edge;
			out.getContext('2d')?.drawImage(image, crop.sx, crop.sy, crop.size, crop.size, 0, 0, edge, edge);
			let blob = await toBlob(out, 'image/webp');
			if (!blob || blob.type !== 'image/webp') blob = await toBlob(out, 'image/jpeg');
			if (!blob) {
				failed = true;
				return;
			}
			const extension = blob.type === 'image/webp' ? 'webp' : 'jpg';
			onCropped(new File([blob], `avatar.${extension}`, { type: blob.type }));
		} finally {
			working = false;
		}
	}
</script>

<BottomSheet title={m('account.crop.title')} onClose={onCancel}>
	{#if failed}
		<p class="text-sm text-error mb-4">{m('account.crop.failed')}</p>
	{:else}
		<div class="flex flex-col items-center gap-4">
			<canvas
				bind:this={canvas}
				class="w-64 h-64 rounded-full bg-surface-container touch-none cursor-grab active:cursor-grabbing"
				aria-label={m('account.crop.hint')}
				onpointerdown={onPointerDown}
				onpointermove={onPointerMove}
				onpointerup={() => (dragStart = null)}
				onpointercancel={() => (dragStart = null)}
			></canvas>
			<p class="text-xs text-on-surface-variant">{m('account.crop.hint')}</p>
			<label class="w-full flex items-center gap-3 text-on-surface-variant">
				<span class="material-symbols-outlined text-[20px]" aria-hidden="true">zoom_out</span>
				<span class="sr-only">{m('account.crop.zoom')}</span>
				<input
					type="range"
					min={MIN_ZOOM}
					max={MAX_ZOOM}
					step="0.01"
					value={zoom}
					oninput={onZoom}
					class="flex-1 accent-primary"
				/>
				<span class="material-symbols-outlined text-[20px]" aria-hidden="true">zoom_in</span>
			</label>
		</div>
	{/if}
	<div class="flex flex-col gap-2 mt-6">
		<Button fullWidth loading={working} disabled={!image || failed} onclick={confirm}>
			{m('account.crop.use')}
		</Button>
		<button
			type="button"
			class="w-full py-3 text-sm font-label font-bold text-on-surface-variant"
			onclick={onCancel}>{m('common.cancel')}</button
		>
	</div>
</BottomSheet>
