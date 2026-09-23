import assert from 'node:assert/strict';
import test from 'node:test';

const collections = [
  'platformReleaseManifests',
  'platformActiveReleasePointers',
  'platformFeatureFlagRevisions',
  'referenceMarketConfigRevisions',
  'referenceActivationPointers',
  'privacyRequests',
  'privacyDomainTasks',
  'securityAuditEvents',
  'identityAccounts',
  'identityProviderLinks',
  'identitySessions',
  'identityCreatorVerifications',
  'identityManagedPages',
  'identityPageMemberships',
] as const;

void test('all exact R1 Firestore collections deny direct client reads and writes', async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/u);
  for (const collection of collections) {
    const url = `http://${host}/v1/projects/demo-recharge/databases/(default)/documents/${collection}/client-probe`;
    const read = await fetch(url);
    const write = await fetch(url, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ fields: { status: { stringValue: 'disabled' } } }),
    });
    assert.ok(read.status === 401 || read.status === 403, `${collection} read: ${read.status}`);
    assert.ok(write.status === 401 || write.status === 403, `${collection} write: ${write.status}`);
  }
});
