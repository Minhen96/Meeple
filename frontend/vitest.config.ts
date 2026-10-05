import { fileURLToPath } from 'node:url';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { svelteTesting } from '@testing-library/svelte/vite';
import { defineConfig } from 'vitest/config';

const stub = (name: string) => fileURLToPath(new URL(`./src/test/stubs/${name}`, import.meta.url));

/**
 * Unit-test config, deliberately separate from vite.config.ts.
 *
 * Vitest runs Vite in serve mode, where the sveltekit() plugin calls
 * adapter-cloudflare's emulate() -> wrangler getPlatformProxy(), which boots a
 * local workerd/miniflare instance that is never disposed. Its open handles
 * kept the process alive after the tests passed ("close timed out after
 * 10000ms ... something prevents Vite server from exiting"). So this config
 * uses the plain svelte() plugin (enough to compile components for
 * @testing-library/svelte) plus the $lib alias. $app/* and $env/* resolve to
 * small stubs under src/test/stubs; tests that care about their behaviour
 * still override them with vi.mock().
 *
 * Plain TypeScript tests (*.test.ts) run in node; component tests
 * (*.svelte.test.ts) run in jsdom.
 */
export default defineConfig({
	// Auto-cleanup is registered in src/test/setup.ts for component tests only.
	plugins: [svelte({ hot: false }), svelteTesting({ autoCleanup: false })],
	resolve: {
		alias: {
			$lib: fileURLToPath(new URL('./src/lib', import.meta.url)),
			'$app/environment': stub('app-environment.ts'),
			'$app/navigation': stub('app-navigation.ts'),
			'$app/state': stub('app-state.ts'),
			'$app/stores': stub('app-stores.ts'),
			'$env/dynamic/private': stub('env-dynamic-private.ts'),
			'$env/dynamic/public': stub('env-dynamic-public.ts')
		}
	},
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}'],
		environment: 'node',
		environmentMatchGlobs: [['src/**/*.svelte.test.ts', 'jsdom']],
		setupFiles: ['./src/test/setup.ts'],
		coverage: {
			provider: 'v8',
			// Scope: the non-component TypeScript (api clients, stores, utils, i18n,
			// session, load functions, hooks). Svelte components are exercised by the
			// *.svelte.test.ts suites but are not counted toward the thresholds.
			include: [
				'src/lib/**/*.ts',
				'src/routes/**/*.ts',
				'src/hooks.server.ts',
				'src/hooks.client.ts'
			],
			exclude: [
				'**/*.d.ts',
				'**/*.test.ts',
				'**/*.spec.ts',
				'src/test/**',
				// Types-only modules: nothing executable to cover.
				'src/lib/types/**',
				'src/lib/i18n/types.ts'
			],
			reporter: ['text', 'text-summary', 'json-summary', 'html'],
			reportsDirectory: './coverage',
			thresholds: {
				lines: 85,
				branches: 75
			}
		}
	}
});
