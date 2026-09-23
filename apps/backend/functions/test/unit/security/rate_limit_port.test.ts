import assert from 'node:assert/strict';
import test from 'node:test';

import { LocalDenyRateLimitPort } from '../../../src/security/rate_limit_port.js';

void test('local R1 rate limit decisions are bounded and deny by default', async () => {
  const port = new LocalDenyRateLimitPort();
  assert.deepEqual(
    await port.decide({ bucket: 'platform.read', subjectHash: 'a'.repeat(64), cost: 1 }),
    { allowed: false, retryAfterSeconds: 60 },
  );
  assert.throws(
    () => void port.decide({ bucket: 'platform.read', subjectHash: 'a'.repeat(64), cost: 0 }),
    /rate_limit_cost_invalid/,
  );
  assert.throws(
    () => void port.decide({ bucket: 'platform.read', subjectHash: 'raw-user-id', cost: 1 }),
    /rate_limit_request_invalid/,
  );
});
