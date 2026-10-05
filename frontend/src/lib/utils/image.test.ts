import { describe, expect, it } from 'vitest';
import {
	MIN_DIMENSION,
	POST_IMAGE_MAX_DIMENSION,
	QUALITY_STEPS,
	compressionPlan,
	fitWithin,
	formatBytes,
	withExtension
} from './image';

describe('fitWithin', () => {
	it('scales landscape and portrait images so the longest side is the max', () => {
		expect(fitWithin({ width: 4000, height: 3000 }, 1200)).toEqual({
			width: 1200,
			height: 900
		});
		expect(fitWithin({ width: 3024, height: 4032 }, 1200)).toEqual({
			width: 900,
			height: 1200
		});
	});

	it('never upscales', () => {
		expect(fitWithin({ width: 800, height: 600 }, 1200)).toEqual({
			width: 800,
			height: 600
		});
		expect(fitWithin({ width: 1200, height: 1200 }, 1200)).toEqual({
			width: 1200,
			height: 1200
		});
	});

	it('keeps extreme aspect ratios at least one pixel wide', () => {
		expect(fitWithin({ width: 10000, height: 2 }, 1200)).toEqual({
			width: 1200,
			height: 1
		});
	});

	it('rejects empty images', () => {
		expect(() => fitWithin({ width: 0, height: 10 }, 1200)).toThrow();
	});
});

describe('compressionPlan', () => {
	it('tries every quality at the fitted size first', () => {
		const plan = compressionPlan({ width: 4000, height: 3000 });
		expect(plan.slice(0, QUALITY_STEPS.length)).toEqual(
			QUALITY_STEPS.map((quality) => ({
				size: { width: 1200, height: 900 },
				quality
			}))
		);
	});

	it('then shrinks by 20% per round down to the minimum dimension', () => {
		const plan = compressionPlan({ width: 4000, height: 3000 });
		const sizes = [...new Set(plan.map((a) => Math.max(a.size.width, a.size.height)))];
		expect(sizes[0]).toBe(POST_IMAGE_MAX_DIMENSION);
		expect(sizes[1]).toBe(960);
		expect(sizes.at(-1)).toBe(MIN_DIMENSION);
		for (let i = 1; i < sizes.length; i++) expect(sizes[i]).toBeLessThan(sizes[i - 1]);
		expect(plan.length % QUALITY_STEPS.length).toBe(0);
	});

	it('stops after one round for small images', () => {
		expect(compressionPlan({ width: 200, height: 100 })).toHaveLength(QUALITY_STEPS.length);
	});

	it('respects a custom maximum (avatars)', () => {
		expect(compressionPlan({ width: 2000, height: 2000 }, 400)[0].size).toEqual({
			width: 400,
			height: 400
		});
	});
});

describe('formatting helpers', () => {
	it('formats byte sizes', () => {
		expect(formatBytes(512)).toBe('512 B');
		expect(formatBytes(640 * 1024)).toBe('640 KB');
		expect(formatBytes(1.25 * 1024 * 1024)).toBe('1.3 MB');
	});

	it('replaces the file extension', () => {
		expect(withExtension('IMG_0001.HEIC', 'webp')).toBe('IMG_0001.webp');
		expect(withExtension('photo', 'webp')).toBe('photo.webp');
		expect(withExtension('.png', 'webp')).toBe('image.webp');
		expect(withExtension('my.trip.jpeg', 'jpg')).toBe('my.trip.jpg');
	});
});
