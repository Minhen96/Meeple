// Test stub for $app/navigation (aliased in vitest.config.ts). Assert on these with vi.mocked().
import { vi } from 'vitest';

export const goto = vi.fn(async (..._args: unknown[]) => {});
export const invalidate = vi.fn(async (..._args: unknown[]) => {});
export const invalidateAll = vi.fn(async () => {});
export const preloadData = vi.fn(async (..._args: unknown[]) => {});
export const preloadCode = vi.fn(async (..._args: unknown[]) => {});
export const beforeNavigate = vi.fn();
export const afterNavigate = vi.fn();
export const onNavigate = vi.fn();
export const pushState = vi.fn();
export const replaceState = vi.fn();
export const disableScrollHandling = vi.fn();
