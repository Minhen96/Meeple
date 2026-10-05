/**
 * Client-side image compression before upload (FEATURES_COMPLETE section 0, TECH_STACK_ADDITIONS 18):
 * re-encode to WebP, longest side at most 1200px, at most 1 MB. Re-encoding through a canvas also
 * strips EXIF metadata (GPS position).
 *
 * The sizing/quality plan is pure and unit-tested; `compressImage` drives a canvas in the browser.
 */

export const POST_IMAGE_MAX_DIMENSION = 1200;
export const POST_IMAGE_MAX_BYTES = 1024 * 1024;
export const AVATAR_MAX_DIMENSION = 400;
export const AVATAR_MAX_BYTES = 200 * 1024;

/** Encoder qualities tried in order at each size before shrinking further. */
export const QUALITY_STEPS = [0.85, 0.75, 0.65, 0.5] as const;
/** Each extra round shrinks the dimensions by this factor. */
export const SHRINK_FACTOR = 0.8;
/** Never shrink below this longest side; the smallest attempt is accepted as is. */
export const MIN_DIMENSION = 320;

export interface Size {
	width: number;
	height: number;
}

export interface CompressOptions {
	maxDimension?: number;
	maxBytes?: number;
	/** Called with 0–1 as attempts proceed (for a per-image progress bar). */
	onProgress?: (fraction: number) => void;
}

export interface CompressedImage {
	file: File;
	width: number;
	height: number;
	originalBytes: number;
}

/** Scales `size` down (never up) so its longest side is at most `max`, keeping the aspect ratio. */
export function fitWithin(size: Size, max: number): Size {
	const { width, height } = size;
	if (width <= 0 || height <= 0) throw new Error('Image has no dimensions');
	const longest = Math.max(width, height);
	if (longest <= max) return { width, height };
	const scale = max / longest;
	return {
		width: Math.max(1, Math.round(width * scale)),
		height: Math.max(1, Math.round(height * scale))
	};
}

export interface Attempt {
	size: Size;
	quality: number;
}

/**
 * The encode attempts to try in order: every quality step at the fitted size, then again at
 * successively smaller sizes (×0.8) down to {@link MIN_DIMENSION}. The caller stops at the first
 * result within the byte budget and otherwise keeps the smallest one.
 */
export function compressionPlan(source: Size, maxDimension = POST_IMAGE_MAX_DIMENSION): Attempt[] {
	const attempts: Attempt[] = [];
	let size = fitWithin(source, maxDimension);
	for (;;) {
		for (const quality of QUALITY_STEPS) attempts.push({ size, quality });
		const longest = Math.max(size.width, size.height);
		if (longest <= MIN_DIMENSION) break;
		const next = fitWithin(size, Math.max(MIN_DIMENSION, Math.floor(longest * SHRINK_FACTOR)));
		if (next.width === size.width && next.height === size.height) break;
		size = next;
	}
	return attempts;
}

/** "1.2 MB" / "640 KB" for showing the compressed size under a thumbnail. */
export function formatBytes(bytes: number): string {
	if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
	if (bytes >= 1024) return `${Math.round(bytes / 1024)} KB`;
	return `${bytes} B`;
}

/** `photo.HEIC` → `photo.webp`. */
export function withExtension(name: string, extension: string): string {
	const base = name.replace(/\.[^./\\]+$/, '') || 'image';
	return `${base}.${extension}`;
}

// ─── Browser-only encoding ──────────────────────────────────────────────────

async function decode(
	file: File
): Promise<{ source: CanvasImageSource; size: Size; close: () => void }> {
	if (typeof createImageBitmap === 'function') {
		const bitmap = await createImageBitmap(file);
		return {
			source: bitmap,
			size: { width: bitmap.width, height: bitmap.height },
			close: () => bitmap.close()
		};
	}
	const url = URL.createObjectURL(file);
	try {
		const img = new Image();
		img.src = url;
		await img.decode();
		return {
			source: img,
			size: { width: img.naturalWidth, height: img.naturalHeight },
			close: () => URL.revokeObjectURL(url)
		};
	} catch (err) {
		URL.revokeObjectURL(url);
		throw err;
	}
}

function encode(
	source: CanvasImageSource,
	size: Size,
	type: string,
	quality: number
): Promise<Blob> {
	const canvas = document.createElement('canvas');
	canvas.width = size.width;
	canvas.height = size.height;
	const ctx = canvas.getContext('2d');
	if (!ctx) return Promise.reject(new Error('Canvas is not available'));
	ctx.imageSmoothingQuality = 'high';
	ctx.drawImage(source, 0, 0, size.width, size.height);
	return new Promise((resolve, reject) => {
		canvas.toBlob(
			(blob) => (blob ? resolve(blob) : reject(new Error('Encoding failed'))),
			type,
			quality
		);
	});
}

/**
 * Compresses an image file to WebP within `maxDimension` × `maxBytes`. Browsers that cannot
 * encode WebP (they silently return PNG) fall back to JPEG. Rejects when the file cannot be
 * decoded as an image.
 */
export async function compressImage(
	file: File,
	options: CompressOptions = {}
): Promise<CompressedImage> {
	const maxDimension = options.maxDimension ?? POST_IMAGE_MAX_DIMENSION;
	const maxBytes = options.maxBytes ?? POST_IMAGE_MAX_BYTES;
	const decoded = await decode(file);
	try {
		const plan = compressionPlan(decoded.size, maxDimension);
		let type = 'image/webp';
		let best: { blob: Blob; size: Size } | null = null;
		for (let i = 0; i < plan.length; i++) {
			const { size, quality } = plan[i];
			let blob = await encode(decoded.source, size, type, quality);
			if (blob.type !== type) {
				type = 'image/jpeg';
				blob = await encode(decoded.source, size, type, quality);
			}
			options.onProgress?.((i + 1) / plan.length);
			if (!best || blob.size < best.blob.size) best = { blob, size };
			if (blob.size <= maxBytes) break;
		}
		if (!best) throw new Error('Encoding failed');
		options.onProgress?.(1);
		const extension = best.blob.type === 'image/webp' ? 'webp' : 'jpg';
		return {
			file: new File([best.blob], withExtension(file.name, extension), {
				type: best.blob.type
			}),
			width: best.size.width,
			height: best.size.height,
			originalBytes: file.size
		};
	} finally {
		decoded.close();
	}
}

/** Post photo preset: WebP, ≤ 1200px, ≤ 1 MB. */
export function compressPostImage(
	file: File,
	onProgress?: (fraction: number) => void
): Promise<CompressedImage> {
	return compressImage(file, { onProgress });
}

/** Avatar preset: WebP, ≤ 400px, ≤ 200 KB. */
export function compressAvatar(file: File): Promise<CompressedImage> {
	return compressImage(file, {
		maxDimension: AVATAR_MAX_DIMENSION,
		maxBytes: AVATAR_MAX_BYTES
	});
}
