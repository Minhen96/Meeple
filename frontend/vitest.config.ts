import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

/**
 * Unit-test config, deliberately separate from vite.config.ts.
 *
 * Vitest runs Vite in serve mode, where the sveltekit() plugin calls
 * adapter-cloudflare's emulate() -> wrangler getPlatformProxy(), which boots a
 * local workerd/miniflare instance that is never disposed. Its open handles
 * kept the process alive after the tests passed ("close timed out after
 * 10000ms ... something prevents Vite server from exiting"). Unit tests only
 * cover plain TypeScript modules, so they
 * don't need the SvelteKit/adapter plugin — just the $lib alias. $app/* and
 * $env/* modules must be mocked with vi.mock() in the tests that import them.
 */
export default defineConfig({
	resolve: {
		alias: {
			$lib: fileURLToPath(new URL('./src/lib', import.meta.url))
		}
	},
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}'],
		environment: 'node'
	}
});
