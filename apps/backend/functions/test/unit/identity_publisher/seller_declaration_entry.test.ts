import assert from 'node:assert/strict';
import test from 'node:test';

import { validateIdentityContract } from '../../../src/contracts/validate_identity_contract.js';
import { createLocalIdentityPublisherAuthority } from '../../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { handleSellerDeclarationCommand } from '../../../src/seller_declaration_entry.js';

// ADR 0023 (2026-11-08): the author's own DSA Art. 30 seller declaration over
// the callable contract; the user comes from the authorized Session only.

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
const sessionContext = {
  sessionId: '018FQ2Z8Q9N4M7K2T6V3W1X5YE',
  sessionHandle: 'A'.repeat(43),
  installationId: 'install-1',
};

async function service() {
  const local = createLocalIdentityPublisherAuthority({
    reviewerIds: new Set(['reviewer']),
    pageCreationEnabled: true,
    maximumOwnedPages: 3,
  });
  await local.authority.accounts.ensureAccount({
    proof: { provider: 'google', providerTenant: 'consumer', proof: 'local-test:google:subject-1' },
    proposedUserId: userId,
    proposedIdentityId: '018FQ2Z8Q9N4M7K2T6V3W1X5YC',
    nowUtc: '2026-09-22T00:00:00.000Z',
    accountCreationEnabled: true,
  });
  return local.authority.sellers;
}

const call = async (sellers: Awaited<ReturnType<typeof service>>, data: unknown) => {
  const result = await handleSellerDeclarationCommand({
    userId,
    data,
    service: sellers,
    nowUtc: '2026-11-08T12:00:00.000Z',
  });
  // Every answer matches the result contract.
  assert.equal((await validateIdentityContract('sellerDeclarationResult', result)).ok, true);
  return result;
};

const declare = (expectedRevision: number, declaration: unknown) => ({
  schemaVersion: 1,
  commandType: 'declareSeller',
  requestId: `req-${expectedRevision}`,
  sessionContext,
  expectedRevision,
  declaration,
});

void test('declare, read back, refuse a stale revision and invalid payloads', async () => {
  const sellers = await service();
  const get = {
    schemaVersion: 1,
    commandType: 'getSellerDeclaration',
    requestId: 'get',
    sessionContext,
  };
  assert.deepEqual(await call(sellers, get), { schemaVersion: 1, kind: 'succeeded', data: null });
  const declared = await call(
    sellers,
    declare(0, { status: 'private', contact: { email: 'me@example.com' }, dac7ActivityTypes: [] }),
  );
  assert.equal(declared.kind, 'succeeded');
  assert.equal((declared.data as { userId: string }).userId, userId);
  assert.equal(
    (
      await call(
        sellers,
        declare(0, {
          status: 'private',
          contact: { phone: '+37120000000' },
          dac7ActivityTypes: [],
        }),
      )
    ).code,
    'revision_conflict',
  );
  // A trader without registration data, or a payload naming another user, is refused.
  assert.equal(
    (
      await call(
        sellers,
        declare(1, {
          status: 'trader',
          contact: { email: 'me@example.com' },
          dac7ActivityTypes: [],
        }),
      )
    ).code,
    'invalid_contract',
  );
  assert.equal(
    (await call(sellers, { ...declare(1, {}), userId: 'someone-else' })).code,
    'invalid_contract',
  );
  const read = await call(sellers, get);
  assert.equal((read.data as { revision: number }).revision, 1);
});
