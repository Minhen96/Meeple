// @vitest-environment jsdom
// Browser encoding path of compressImage with a fake canvas / decoder.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AVATAR_MAX_DIMENSION, compressAvatar, compressImage, compressPostImage } from './image';

interface EncodeCall {
	width: number;
	height: number;
	type: string;
	quality: number;
}

let encodes: EncodeCall[];
/** Decides the blob each encode produces. */
let encoder: (call: EncodeCall) => Blob | null;
let hasContext: boolean;

const blobOf = (bytes: number, type: string) => new Blob([new Uint8Array(bytes)], { type });

beforeEach(() => {
	encodes = [];
	hasContext = true;
	encoder = (c) => blobOf(100, c.type);
	vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(function () {
		return hasContext ? ({ drawImage: vi.fn(), imageSmoothingQuality: 'low' } as unknown as CanvasRenderingContext2D) : null;
	} as never);
	vi.spyOn(HTMLCanvasElement.prototype, 'toBlob').mockImplementation(function (
		this: HTMLCanvasElement,
		cb: BlobCallback,
		type?: string,
		quality?: number
	) {
		const call = { width: this.width, height: this.height, type: type ?? '', quality: quality ?? 1 };
		encodes.push(call);
		cb(encoder(call));
	});
	vi.stubGlobal(
		'createImageBitmap',
		vi.fn(async () => ({ width: 4000, height: 3000, close: vi.fn() }))
	);
});

afterEach(() => {
	vi.restoreAllMocks();
	vi.unstubAllGlobals();
});

const input = new File([new Uint8Array(5_000_000)], 'holiday.photo.JPG', { type: 'image/jpeg' });

describe('compressImage', () => {
	it('encodes WebP within the max dimension and stops at the first attempt under the byte limit', async () => {
		const progress: number[] = [];
		const out = await compressPostImage(input, (f) => progress.push(f));
		expect(encodes).toHaveLength(1);
		expect(encodes[0]).toMatchObject({ width: 1200, height: 900, type: 'image/webp', quality: 0.85 });
		expect(out.file.name).toBe('holiday.photo.webp');
		expect(out.file.type).toBe('image/webp');
		expect(out).toMatchObject({ width: 1200, height: 900, originalBytes: input.size });
		expect(progress.at(-1)).toBe(1);
	});

	it('steps quality down until the blob fits, keeping the smallest result', async () => {
		encoder = (c) => blobOf(c.quality >= 0.75 ? 300_000 : 150_000, c.type);
		const out = await compressAvatar(input);
		expect(encodes.map((e) => e.quality)).toEqual([0.85, 0.75, 0.65]);
		expect(encodes[0].width).toBe(AVATAR_MAX_DIMENSION);
		expect(out.file.size).toBe(150_000);
	});

	it('returns the smallest attempt when nothing fits', async () => {
		let n = 0;
		encoder = (c) => blobOf([500, 400, 450, 420, 410, 430, 405, 415, 999, 999, 999, 999][n++] ?? 999, c.type);
		const out = await compressImage(input, { maxBytes: 10 });
		expect(out.file.size).toBe(400);
	});

	it('falls back to JPEG when the browser cannot encode WebP', async () => {
		encoder = (c) => blobOf(100, c.type === 'image/webp' ? 'image/png' : c.type);
		const out = await compressImage(input);
		expect(encodes.map((e) => e.type)).toEqual(['image/webp', 'image/jpeg']);
		expect(out.file.name).toBe('holiday.photo.jpg');
		expect(out.file.type).toBe('image/jpeg');
	});

	it('rejects when the canvas has no 2D context or encoding fails', async () => {
		hasContext = false;
		await expect(compressImage(input)).rejects.toThrow('Canvas is not available');
		hasContext = true;
		encoder = () => null;
		await expect(compressImage(input)).rejects.toThrow('Encoding failed');
	});

	it('closes the decoded bitmap even when encoding fails', async () => {
		const close = vi.fn();
		vi.stubGlobal('createImageBitmap', vi.fn(async () => ({ width: 10, height: 10, close })));
		encoder = () => null;
		await expect(compressImage(input)).rejects.toThrow();
		expect(close).toHaveBeenCalled();
	});
});

/** jsdom has no HTMLImageElement.decode; install one for the test. */
function setDecode(impl: () => Promise<void>) {
	Object.defineProperty(HTMLImageElement.prototype, 'decode', { value: impl, configurable: true, writable: true });
}

describe('decode without createImageBitmap', () => {
	beforeEach(() => {
		vi.stubGlobal('createImageBitmap', undefined);
		URL.createObjectURL = vi.fn(() => 'blob:1');
		URL.revokeObjectURL = vi.fn();
	});

	it('decodes through an <img> and revokes the object URL', async () => {
		setDecode(async () => undefined);
		vi.spyOn(HTMLImageElement.prototype, 'naturalWidth', 'get').mockReturnValue(800);
		vi.spyOn(HTMLImageElement.prototype, 'naturalHeight', 'get').mockReturnValue(600);
		const out = await compressImage(input);
		expect(out).toMatchObject({ width: 800, height: 600 });
		expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:1');
	});

	it('rejects undecodable files and still revokes the URL', async () => {
		setDecode(async () => {
			throw new Error('not an image');
		});
		await expect(compressImage(input)).rejects.toThrow('not an image');
		expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:1');
	});
});
