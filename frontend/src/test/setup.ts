// Shared Vitest setup. jest-dom matchers are only meaningful in the jsdom
// environment (component tests), but registering them under node is harmless.
import '@testing-library/jest-dom/vitest';

// jsdom has no Web Animations API, which Svelte transitions (fade, fly, slide)
// use. A minimal Animation that finishes on the next macrotask lets intro/outro
// transitions complete so components mount and unmount as in a browser.
if (typeof Element !== 'undefined' && typeof Element.prototype.animate !== 'function') {
	Element.prototype.animate = function animate(): Animation {
		const animation = {
			playState: 'running',
			currentTime: 0,
			effect: null,
			onfinish: null as null | (() => void),
			cancel() {
				animation.playState = 'idle';
			},
			finish() {
				animation.playState = 'finished';
				animation.onfinish?.();
			},
			finished: Promise.resolve()
		};
		setTimeout(() => {
			if (animation.playState === 'running') animation.finish();
		}, 0);
		return animation as unknown as Animation;
	};
}
