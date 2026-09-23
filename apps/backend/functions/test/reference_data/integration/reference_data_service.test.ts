import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ReferenceDataService,
  referenceDataPointerKey,
} from '../../../src/modules/reference_data/application/reference_data_service.js';
import { InMemoryMarketConfigRepository } from '../../../src/platform/config/market_config_repository.js';
import { buildMarketConfig, fixtureIds } from '../../support/platform_fixtures.js';

void test('publication is immutable and activation pointer is explicit CAS', async () => {
  const repository = new InMemoryMarketConfigRepository();
  const service = new ReferenceDataService(repository);
  const config = buildMarketConfig();
  await service.publishMarketConfig(config);
  assert.equal((await service.activateMarketConfig(config, 0)).swapped, true);
  assert.equal(
    (await repository.getActivePointer(referenceDataPointerKey('local', 'LV')))?.activeRevisionId,
    fixtureIds.first,
  );
  assert.deepEqual(await service.activateMarketConfig(config, 0), {
    swapped: false,
    reason: 'revision_conflict',
  });
});

void test('rollback only accepts same environment, market and compatibility key', async () => {
  const repository = new InMemoryMarketConfigRepository();
  const service = new ReferenceDataService(repository);
  const current = buildMarketConfig({
    id: fixtureIds.second,
    revision: 2,
    supersedesRevisionId: fixtureIds.first,
  });
  const target = buildMarketConfig({ id: fixtureIds.first, revision: 1 });
  await service.publishMarketConfig(current);
  await service.publishMarketConfig(target);
  await service.activateMarketConfig(current, 0);
  assert.equal((await service.rollbackMarketConfig(current, target, 1)).swapped, true);
  const otherMarket = buildMarketConfig({ id: fixtureIds.third, marketId: 'EE' });
  await service.publishMarketConfig(otherMarket);
  assert.deepEqual(await service.rollbackMarketConfig(current, otherMarket, 2), {
    swapped: false,
    reason: 'incompatible_rollback',
  });
});
