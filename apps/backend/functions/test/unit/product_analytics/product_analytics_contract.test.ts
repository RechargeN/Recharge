import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  parseProductAnalyticsBatch,
  parseProductAnalyticsEvent,
  productAnalyticsDataClass,
  productAnalyticsEnums,
  productAnalyticsEventRegistry,
  productAnalyticsLegalBasisRef,
  productAnalyticsLimits,
  productAnalyticsPurposeId,
  productAnalyticsRegistryRevision,
  productAnalyticsSubjectMode,
} from '../../../src/modules/product_analytics/product_analytics_contract.js';
import {
  acceptedProductAnalyticsPolicy,
  unresolvedProductAnalyticsPolicy,
  type ProductAnalyticsCollectionPolicy,
} from '../../../src/modules/product_analytics/product_analytics_policy.js';

/**
 * L3 contract: the typed registry equals the canonical JSON, and the shared
 * synthetic corpus passes or fails exactly as declared (the mobile test reads
 * the same files). Policy admission is fail-closed.
 */
const contractRoot = path.resolve(
  process.cwd(),
  '../../../packages/api_contracts/schema/product_analytics/v1',
);
const read = (file: string) =>
  JSON.parse(readFileSync(path.join(contractRoot, file), 'utf8')) as Record<string, unknown>;
const registry = read('product_analytics_event_registry.v1.json');
const corpus = read('fixtures/product_analytics_corpus.v1.json') as {
  validEvents: Record<string, unknown>[];
  invalidEvents: {
    case: string;
    patch?: Record<string, unknown>;
    fields?: Record<string, unknown>;
    rawFields?: string;
    eventName?: string;
  }[];
  invalidBatches: { case: string; batch?: Record<string, unknown>; repeatValidEvents?: number }[];
};

void test('L3-T-CONTRACT: the TypeScript registry equals the canonical JSON registry', () => {
  assert.deepEqual(
    JSON.parse(
      JSON.stringify({
        schemaVersion: 1,
        registryRevision: productAnalyticsRegistryRevision,
        purposeId: productAnalyticsPurposeId,
        legalBasisRef: productAnalyticsLegalBasisRef,
        subjectMode: productAnalyticsSubjectMode,
        dataClass: productAnalyticsDataClass,
        limits: productAnalyticsLimits,
        enums: productAnalyticsEnums,
        events: productAnalyticsEventRegistry,
      }),
    ),
    registry,
  );
});

function invalidEvent(item: (typeof corpus.invalidEvents)[number]): Record<string, unknown> {
  const base =
    item.eventName === undefined
      ? corpus.validEvents[0]!
      : corpus.validEvents.find((candidate) => candidate.eventName === item.eventName)!;
  const event: Record<string, unknown> = { ...base, ...(item.patch ?? {}) };
  if (item.fields !== undefined) event.fields = item.fields;
  if (item.rawFields !== undefined) event.fields = JSON.parse(item.rawFields) as unknown;
  return event;
}

void test('L3-T-CONTRACT corpus: valid events pass, every invalid case is rejected', () => {
  for (const event of corpus.validEvents)
    assert.ok(parseProductAnalyticsEvent(event), String(event.eventName));
  assert.ok(corpus.invalidEvents.length >= 25);
  for (const item of corpus.invalidEvents)
    assert.equal(parseProductAnalyticsEvent(invalidEvent(item)), null, item.case);
  for (const item of corpus.invalidBatches) {
    const batch =
      item.repeatValidEvents === undefined
        ? item.case === 'batch_empty' || !Array.isArray(item.batch!.events)
          ? item.batch!
          : { ...item.batch!, events: [corpus.validEvents[0]] }
        : { schemaVersion: 1, events: Array(item.repeatValidEvents).fill(corpus.validEvents[0]) };
    assert.equal(parseProductAnalyticsBatch(batch), null, item.case);
  }
  const oversized = {
    schemaVersion: 1,
    events: Array.from({ length: 20 }, () => ({
      ...corpus.validEvents[0],
      policyRevision: 'x'.repeat(420),
    })),
  };
  assert.equal(parseProductAnalyticsBatch(oversized), null);
});

void test('L3-T-CONTRACT batch: an invalid event is rejected alone and only a UUID is echoed', () => {
  const entries = parseProductAnalyticsBatch({
    schemaVersion: 1,
    events: [
      corpus.validEvents[0],
      { ...corpus.validEvents[1], eventId: 'L3SYNTH-not-an-id', fields: { query: 'x' } },
      { ...corpus.validEvents[2], fields: { create_type: 'event', outcome: 'L3SYNTH' } },
    ],
  });
  assert.ok(entries);
  assert.deepEqual(
    entries.map((entry) => (entry.valid ? 'valid' : entry.eventId)),
    ['valid', null, corpus.validEvents[2]!.eventId],
  );
});

function policy(overrides: Partial<ProductAnalyticsCollectionPolicy> = {}) {
  return {
    policyRevision: 'synthetic-l3-policy-1',
    purposeId: 'product_usage_measurement',
    marketId: 'LV',
    legalBasisRef: 'synthetic-test-only-basis',
    consentRequired: true,
    eventNames: ['details_opened'],
    rawRetentionHours: 48,
    aggregateRetentionHours: 72,
    acceptanceWindowHours: 24,
    queueMaxAgeHours: 24,
    effectiveFromUtc: '2026-10-01T00:00:00.000Z',
    expiresAtUtc: '2026-12-01T00:00:00.000Z',
    source: 'synthetic-test-only',
    ...overrides,
  } as ProductAnalyticsCollectionPolicy;
}

void test('L3-T-POLICY: the production default has no policy; inconsistent policies are refused', () => {
  const now = '2026-10-25T12:00:00.000Z';
  assert.equal(
    acceptedProductAnalyticsPolicy(unresolvedProductAnalyticsPolicy.effective(now), now),
    null,
  );
  assert.ok(acceptedProductAnalyticsPolicy(policy(), now));
  for (const [name, broken] of Object.entries({
    windowNotShorterThanRetention: policy({ acceptanceWindowHours: 48 }),
    queueOutlivesWindow: policy({ queueMaxAgeHours: 25 }),
    productionSource: policy({ source: 'production' as never }),
    noLegalBasis: policy({ legalBasisRef: '' }),
    otherMarket: policy({ marketId: 'EE' as never }),
    otherPurpose: policy({ purposeId: 'advertising' as never }),
    unknownEvent: policy({ eventNames: ['search_query_entered' as never] }),
    zeroRetention: policy({ rawRetentionHours: 0 }),
    expired: policy({ expiresAtUtc: now }),
    notYetEffective: policy({ effectiveFromUtc: '2026-10-26T00:00:00.000Z' }),
  }))
    assert.equal(acceptedProductAnalyticsPolicy(broken, now), null, name);
});
