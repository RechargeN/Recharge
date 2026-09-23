import assert from 'node:assert/strict';
import test from 'node:test';

import { referenceDataPointerKey } from '../../../src/modules/reference_data/application/reference_data_service.js';
import { buildMarketConfig, fixtureIds } from '../../support/platform_fixtures.js';

void test('LV, EE and LT remain independent and disabled', () => {
  const configs = [
    buildMarketConfig({ id: fixtureIds.first, marketId: 'LV' }),
    buildMarketConfig({ id: fixtureIds.second, marketId: 'EE' }),
    buildMarketConfig({ id: fixtureIds.third, marketId: 'LT' }),
  ];
  assert.ok(configs.every((config) => config.status === 'disabled'));
  assert.equal(
    new Set(configs.map((config) => referenceDataPointerKey(config.environmentId, config.marketId)))
      .size,
    3,
  );
  assert.deepEqual(
    configs.map((config) => config.defaultIanaZone),
    ['Europe/Riga', 'Europe/Tallinn', 'Europe/Vilnius'],
  );
  assert.ok(configs.every((config) => config.currencyCodes[0] === 'EUR'));
});
