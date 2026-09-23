import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createMarketConfigRevision,
  referenceDataCapabilityId,
} from '../../../src/modules/reference_data/domain/market_config.js';
import { referenceDataPointerKey } from '../../../src/modules/reference_data/application/reference_data_service.js';
import {
  buildMarketConfig,
  emptyPolicyPointers,
  fixtureIds,
} from '../../support/platform_fixtures.js';

void test('market config is isolated by environment, market and capability', () => {
  const config = buildMarketConfig();
  assert.equal(
    referenceDataPointerKey(config.environmentId, config.marketId),
    `local:LV:${referenceDataCapabilityId}`,
  );
  assert.equal(config.status, 'disabled');
  assert.deepEqual(config.currencyCodes, ['EUR']);
});

void test('default locale must be explicitly supported', () => {
  assert.throws(
    () =>
      createMarketConfigRevision({
        revisionId: fixtureIds.first,
        revisionNumber: 1,
        environmentId: 'local',
        marketId: 'LV',
        countryCode: 'LV',
        status: 'disabled',
        primaryLocale: 'en-LV',
        supportedLocales: ['lv-LV'],
        fallbackLocaleOrder: ['lv-LV'],
        languageFallbacks: {},
        currencyCodes: ['EUR'],
        defaultIanaZone: 'Europe/Riga',
        allowedIanaZones: ['Europe/Riga'],
        taxonomyRevisionRef: { taxonomyId: 'category-system', revision: '1.4.3' },
        mandatoryCopyManifestRevision: null,
        sourceRecordIds: [],
        policyPointers: emptyPolicyPointers,
        capabilityMatrix: [
          {
            capabilityId: 'platform.foundation',
            status: 'disabled',
            requiresMandatoryCopy: false,
            mandatoryCopyPurposeId: null,
            requiresEligibleSources: false,
          },
        ],
        compatibilityKey: 'reference-data-v1',
        contentHash: `sha256:${'b'.repeat(64)}`,
        supersedesRevisionId: null,
        createdAtUtc: '2026-09-21T10:00:00.000Z',
      }),
    /primary_locale_unsupported/,
  );
});
