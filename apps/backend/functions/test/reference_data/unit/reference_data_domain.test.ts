import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveLocalizedText } from '../../../src/modules/reference_data/application/resolve_localized_text.js';
import { evaluateMarketCapability } from '../../../src/modules/reference_data/application/evaluate_market_capability.js';
import { createLocalizedText } from '../../../src/modules/reference_data/domain/localized_text.js';
import {
  createSourceRecord,
  isSourceEligible,
} from '../../../src/modules/reference_data/domain/source_provenance.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { buildMarketConfig, fixtureIds } from '../../support/platform_fixtures.js';

void test('localized text reports every fallback instead of hiding it', () => {
  const text = createLocalizedText({
    defaultLocale: 'lv-LV',
    values: { 'lv-LV': 'Nosaukums', en: 'Title' },
  });
  const config = buildMarketConfig();
  const exact = resolveLocalizedText({ text, requestedLocale: 'lv-LV', marketConfig: config });
  assert.deepEqual(exact.ok && [exact.resolutionKind, exact.resolvedLocale], ['exact', 'lv-LV']);
  const fallback = resolveLocalizedText({ text, requestedLocale: 'ru-LV', marketConfig: config });
  assert.equal(fallback.ok, true);
  if (fallback.ok) {
    assert.equal(fallback.resolutionKind, 'market_fallback');
    assert.equal(fallback.requestedLocaleSupported, false);
  }
  assert.deepEqual(
    resolveLocalizedText({
      text,
      requestedLocale: 'ru-LV',
      marketConfig: config,
      fallbackPolicy: 'forbidden',
    }),
    { ok: false, code: 'fallback_forbidden', requestedLocale: 'ru-LV' },
  );
});

void test('unaccepted source is never eligible', () => {
  const source = createSourceRecord({
    sourceRecordId: fixtureIds.first,
    sourceKind: 'external',
    sourceRevision: 'candidate-v1',
    originUri: 'https://example.invalid/source',
    evidenceSha256: 'a'.repeat(64),
    licenseDecision: 'pending',
    licenseEvidenceRevision: null,
    eligibility: 'candidate',
    marketScope: ['LV'],
    capturedAtUtc: '2026-09-21T10:00:00.000Z',
    expiresAtUtc: null,
  });
  assert.equal(isSourceEligible(source, 'LV', parseUtcInstant('2026-09-21T11:00:00.000Z')), false);
});

void test('missing mandatory copy blocks only the dependent capability', () => {
  const base = buildMarketConfig();
  const booking = {
    ...base,
    capabilityMatrix: [
      ...base.capabilityMatrix,
      {
        capabilityId: 'booking.create',
        status: 'disabled' as const,
        requiresMandatoryCopy: true,
        mandatoryCopyPurposeId: 'booking.terms',
        requiresEligibleSources: false,
      },
    ],
  };
  const nowUtc = parseUtcInstant('2026-09-21T11:00:00.000Z');
  assert.ok(
    evaluateMarketCapability({
      config: booking,
      capabilityId: 'booking.create',
      requestedLocale: 'lv-LV',
      mandatoryCopies: [],
      sources: [],
      nowUtc,
    }).blockers.includes('mandatory_copy_missing'),
  );
  assert.equal(
    evaluateMarketCapability({
      config: booking,
      capabilityId: 'platform.foundation',
      requestedLocale: 'lv-LV',
      mandatoryCopies: [],
      sources: [],
      nowUtc,
    }).blockers.includes('mandatory_copy_missing'),
    false,
  );
});
