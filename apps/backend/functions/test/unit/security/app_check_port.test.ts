import assert from 'node:assert/strict';
import test from 'node:test';

import {
  appCheckGrantsAuthority,
  LocalDenyAppCheckPort,
} from '../../../src/security/app_check_port.js';

void test('App Check is fail-closed and never grants authorization', async () => {
  const evidence = await new LocalDenyAppCheckPort().verify(undefined);
  assert.deepEqual(evidence, { state: 'missing' });
  assert.equal(appCheckGrantsAuthority({ state: 'valid', tokenAgeSeconds: 0 }), false);
});
