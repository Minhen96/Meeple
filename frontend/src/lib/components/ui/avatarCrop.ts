/**
 * Square (1:1) avatar crop math, kept free of DOM so it is unit-tested.
 *
 * The cropper shows the image "cover"-fitted in a square viewport of `viewport` CSS pixels,
 * scaled further by `zoom` (>= 1) and moved by `offset` (CSS pixels, 0 = centred). The visible
 * square maps back to a source rectangle that is drawn into an `output`-sized canvas.
 */

export interface Size {
	width: number;
	height: number;
}

export interface Point {
	x: number;
	y: number;
}

export interface CropRect {
	sx: number;
	sy: number;
	size: number;
}

export const MIN_ZOOM = 1;
export const MAX_ZOOM = 4;
/** Output edge in pixels: 512px is plenty for a 128px avatar on 4x screens. */
export const AVATAR_OUTPUT_SIZE = 512;

export function clampZoom(zoom: number): number {
	if (!Number.isFinite(zoom)) return MIN_ZOOM;
	return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, zoom));
}

/** Displayed image size (CSS px) when cover-fitted in the viewport at `zoom`. */
export function displayedSize(image: Size, viewport: number, zoom: number): Size {
	const scale = (viewport / Math.min(image.width, image.height)) * clampZoom(zoom);
	return { width: image.width * scale, height: image.height * scale };
}

/** Keeps the image covering the whole viewport: the offset may not reveal empty space. */
export function clampOffset(offset: Point, image: Size, viewport: number, zoom: number): Point {
	const shown = displayedSize(image, viewport, zoom);
	const maxX = Math.max(0, (shown.width - viewport) / 2);
	const maxY = Math.max(0, (shown.height - viewport) / 2);
	return {
		x: Math.min(maxX, Math.max(-maxX, offset.x)),
		y: Math.min(maxY, Math.max(-maxY, offset.y))
	};
}

/** Source square (image pixels) behind the visible viewport. */
export function cropRect(image: Size, viewport: number, zoom: number, offset: Point): CropRect {
	if (image.width <= 0 || image.height <= 0 || viewport <= 0) {
		return { sx: 0, sy: 0, size: 0 };
	}
	const z = clampZoom(zoom);
	const clamped = clampOffset(offset, image, viewport, z);
	const scale = (viewport / Math.min(image.width, image.height)) * z;
	const size = viewport / scale;
	const centreX = image.width / 2 - clamped.x / scale;
	const centreY = image.height / 2 - clamped.y / scale;
	const sx = Math.min(image.width - size, Math.max(0, centreX - size / 2));
	const sy = Math.min(image.height - size, Math.max(0, centreY - size / 2));
	return { sx, sy, size };
}

/** Output edge: never upscale beyond the source crop, never exceed `max`. */
export function outputSize(crop: CropRect, max: number = AVATAR_OUTPUT_SIZE): number {
	return Math.max(1, Math.min(max, Math.round(crop.size)));
}
