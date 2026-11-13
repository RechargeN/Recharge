import assert from 'node:assert/strict';
import test from 'node:test';

import {
  InMemoryReleaseManifestRepository,
  releaseScopeKey,
} from '../../../src/platform/release/release_manifest_repository.js';
import { ReleaseService } from '../../../src/platform/release/release_service.js';
import { buildRelease, fixtureIds } from '../../support/platform_fixtures.js';

void test('release publication is idempotent and pointer activation is optimistic', async () => {
  const repository = new InMemoryReleaseManifestRepository();
  const service = new ReleaseService(repository);
  const manifest = buildRelease();
  await service.publish(manifest);
  await service.publish(manifest);
  const [first, second] = await Promise.all([
    service.activate(manifest, 0),
    service.activate(manifest, 0),
  ]);
  assert.equal([first, second].filter((result) => result.swapped).length, 1);
  assert.equal(
    (await repository.getActivePointer(releaseScopeKey('local', 'LV', 'platform.foundation')))
      ?.activeManifestId,
    fixtureIds.first,
  );
});

void test('same manifest id cannot be overwritten', async () => {
  const repository = new InMemoryReleaseManifestRepository();
  const first = buildRelease();
  await repository.publish(first);
  const conflicting = { ...first, apiSchemaRevision: 'platform-v2' };
  assert.throws(() => void repository.publish(conflicting), /immutable_release_manifest_conflict/);
});
