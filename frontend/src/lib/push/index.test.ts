import { describe, expect, it } from 'vitest';
import * as push from './index';
import * as fcm from './fcm';

describe('$lib/push barrel', () => {
	it('re-exports the public push API from fcm', () => {
		expect(push.pushApi).toBe(fcm.pushApi);
		expect(push.enablePush).toBe(fcm.enablePush);
		expect(push.disablePush).toBe(fcm.disablePush);
		expect(push.pushStatus).toBe(fcm.pushStatus);
		expect(push.syncPushUser).toBe(fcm.syncPushUser);
		expect(push.isPushConfigured).toBe(fcm.isPushConfigured);
	});
});
