import assert from 'node:assert/strict';
import test from 'node:test';

import { ConfigService } from '../../../src/platform/config/config_service.js';
import { InMemoryFeatureFlagRepository } from '../../../src/platform/config/feature_flag_repository.js';
import {
  InMemoryMarketConfigRepository,
  marketConfigKey,
} from '../../../src/platform/config/market_config_repository.js';
import { ReferenceDataService } from '../../../src/modules/reference_data/application/reference_data_service.js';
import {
  buildFeatureFlag,
  buildMarketConfig,
  fixtureIds,
} from '../../support/platform_fixtures.js';

void test('config service publishes immutable default-off revisions and resolves pointers', async () => {
  const flags = new InMemoryFeatureFlagRepository();
  const markets = new InMemoryMarketConfigRepository();
  const service = new ConfigService(flags);
  const referenceData = new ReferenceDataService(markets);
  const flag = buildFeatureFlag();
  const market = buildMarketConfig();
  await service.publishFeatureFlag(flag);
  await referenceData.publishMarketConfig(market);
  assert.equal((await service.activateFeatureFlag(flag, 0)).swapped, true);
  assert.equal((await referenceData.activateMarketConfig(market, 0)).swapped, true);
  assert.equal(
    (await markets.getActivePointer(marketConfigKey('local', 'LV')))?.activeRevisionId,
    fixtureIds.first,
  );
});

void test('only one concurrent pointer swap wins an expected revision', async () => {
  const flags = new InMemoryFeatureFlagRepository();
  const markets = new InMemoryMarketConfigRepository();
  const service = new ConfigService(flags);
  const referenceData = new ReferenceDataService(markets);
  void service;
  const first = buildMarketConfig({ id: fixtureIds.first, revision: 1 });
  const second = buildMarketConfig({ id: fixtureIds.second, revision: 2 });
  await referenceData.publishMarketConfig(first);
  await referenceData.publishMarketConfig(second);
  const results = await Promise.all([
    referenceData.activateMarketConfig(first, 0),
    referenceData.activateMarketConfig(second, 0),
  ]);
  assert.equal(results.filter((result) => result.swapped).length, 1);
  assert.equal(
    results.filter((result) => !result.swapped && result.reason === 'revision_conflict').length,
    1,
  );
  assert.throws(
    () => void markets.swapActivePointer('local:LV:reference-data.bootstrap', fixtureIds.first, -1),
    /pointer_revision_invalid/,
  );
});
