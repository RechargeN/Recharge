import assert from 'node:assert/strict';
import test from 'node:test';

import { RollbackGuard } from '../../../src/platform/recovery/rollback_guard.js';
import {
  InMemoryReleaseManifestRepository,
  releaseScopeKey,
} from '../../../src/platform/release/release_manifest_repository.js';
import { buildRelease, fixtureIds } from '../../support/platform_fixtures.js';

void test('rollback swaps only to a declared compatible immutable manifest', async () => {
  const repository = new InMemoryReleaseManifestRepository();
  const target = buildRelease({ id: fixtureIds.first, revision: 1 });
  const current = buildRelease({
    id: fixtureIds.second,
    revision: 2,
    rollbackTargetManifestId: fixtureIds.first,
  });
  await repository.publish(target);
  await repository.publish(current);
  await repository.swapActivePointer(
    releaseScopeKey('local', 'LV', 'platform.foundation'),
    current.manifestId,
    0,
  );
  const result = await new RollbackGuard(repository).rollback(current, 1);
  assert.deepEqual(result, {
    rolledBack: true,
    targetManifestId: fixtureIds.first,
    pointerRevision: 2,
  });
});

void test('incompatible rollback remains disabled', async () => {
  const repository = new InMemoryReleaseManifestRepository();
  const target = buildRelease({ id: fixtureIds.first, apiSchemaRevision: 'platform-v2' });
  const current = buildRelease({
    id: fixtureIds.second,
    rollbackTargetManifestId: fixtureIds.first,
  });
  await repository.publish(target);
  await repository.publish(current);
  assert.deepEqual(await new RollbackGuard(repository).rollback(current, 0), {
    rolledBack: false,
    action: 'remain_disabled',
    reason: 'scope_or_contract_incompatible',
  });
});
