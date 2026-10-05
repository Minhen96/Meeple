import { describe, expect, it } from 'vitest';
import {
	AVATAR_OUTPUT_SIZE,
	MAX_ZOOM,
	clampOffset,
	clampZoom,
	cropRect,
	displayedSize,
	outputSize
} from './avatarCrop';

const landscape = { width: 2000, height: 1000 };

describe('avatar crop math', () => {
	it('clamps zoom to the supported range', () => {
		expect(clampZoom(0.5)).toBe(1);
		expect(clampZoom(10)).toBe(MAX_ZOOM);
		expect(clampZoom(Number.NaN)).toBe(1);
		expect(clampZoom(2)).toBe(2);
	});

	it('cover-fits the short side to the viewport', () => {
		expect(displayedSize(landscape, 200, 1)).toEqual({ width: 400, height: 200 });
		expect(displayedSize(landscape, 200, 2)).toEqual({ width: 800, height: 400 });
	});

	it('centres the crop by default', () => {
		expect(cropRect(landscape, 200, 1, { x: 0, y: 0 })).toEqual({ sx: 500, sy: 0, size: 1000 });
	});

	it('follows the drag and zoom', () => {
		// Dragging the image 100 css px to the right reveals more of its left side
		const crop = cropRect(landscape, 200, 1, { x: 100, y: 0 });
		expect(crop.sx).toBe(0);
		const zoomed = cropRect(landscape, 200, 2, { x: 0, y: 0 });
		expect(zoomed).toEqual({ sx: 750, sy: 250, size: 500 });
	});

	it('never reveals empty space', () => {
		expect(clampOffset({ x: 999, y: 50 }, landscape, 200, 1)).toEqual({ x: 100, y: 0 });
		expect(clampOffset({ x: -999, y: -999 }, landscape, 200, 2)).toEqual({ x: -300, y: -100 });
		const crop = cropRect(landscape, 200, 1, { x: -5000, y: 0 });
		expect(crop.sx + crop.size).toBeLessThanOrEqual(landscape.width);
	});

	it('handles degenerate input', () => {
		expect(cropRect({ width: 0, height: 10 }, 200, 1, { x: 0, y: 0 })).toEqual({ sx: 0, sy: 0, size: 0 });
		expect(outputSize({ sx: 0, sy: 0, size: 0 })).toBe(1);
	});

	it('never upscales the output', () => {
		expect(outputSize({ sx: 0, sy: 0, size: 300 })).toBe(300);
		expect(outputSize({ sx: 0, sy: 0, size: 3000 })).toBe(AVATAR_OUTPUT_SIZE);
	});
});
