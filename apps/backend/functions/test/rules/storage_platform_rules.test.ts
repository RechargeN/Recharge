import assert from 'node:assert/strict';
import test from 'node:test';

void test('R1 leaves Storage globally deny-all', async () => {
  const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/u);
  const response = await fetch(
    `http://${host}/v0/b/demo-recharge.appspot.com/o?uploadType=media&name=${encodeURIComponent('platform/probe.txt')}`,
    { method: 'POST', headers: { 'content-type': 'text/plain' }, body: 'probe' },
  );
  assert.ok(
    response.status === 401 || response.status === 403,
    `storage write: ${response.status}`,
  );
});
