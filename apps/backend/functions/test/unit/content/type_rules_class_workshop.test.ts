import assert from 'node:assert/strict';
import test from 'node:test';
import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import {
  classWorkshopLimits,
  classWorkshopMediaIds,
  classWorkshopPastOccurrenceIssues,
  validateClassWorkshopBody,
} from '../../../src/modules/content/domain/type_rules/class_workshop_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import type {
  ContentValidationContext,
  ReferenceLookups,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

const owner = '11111111-1111-4111-8111-111111111111';

async function valid(): Promise<{
  body: Record<string, unknown>;
  context: ContentValidationContext;
}> {
  const fixture = (await readContentJson('fixtures/class_workshop_create_compat.json')) as {
    nowUtc: string;
    cases: { name: string; body: ContentBody }[];
  };
  const ref = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'class_workshop',
  });
  assert.ok(ref.ok);
  return {
    body: structuredClone(fixture.cases.find((item) => item.name === 'valid')!.body),
    context: {
      typeId: 'class_workshop',
      marketId: 'LV',
      publisherRef: { type: 'user', id: owner as never },
      createdByUserId: owner,
      actorUserId: owner,
      nowUtc: fixture.nowUtc,
      draftRevision: 1,
      market: ref.market,
      lookups: ref.lookups,
    },
  };
}

const withLookups = (context: ContentValidationContext, lookups: Partial<ReferenceLookups>) => ({
  ...context,
  lookups: { ...context.lookups, ...lookups },
});

void test('accepted CW-V1 limits are the owner values of CLS-OD-03', () => {
  assert.equal(classWorkshopLimits.fixedSeriesMax, 60);
  assert.equal(classWorkshopLimits.occurrenceMinutesMin, 15);
  assert.equal(classWorkshopLimits.occurrenceMinutesMax, 720);
  assert.equal(classWorkshopLimits.outcomesMax, 10);
  assert.equal(classWorkshopLimits.modulesMax, 20);
  assert.equal(classWorkshopLimits.listItemsMax, 20);
  assert.equal(classWorkshopLimits.groupLimitMax, 500);
  assert.equal(classWorkshopLimits.galleryMax, 10);
  assert.ok(Object.isFrozen(classWorkshopLimits));
});

void test('missing reference authority fails closed instead of assuming validity', async () => {
  const { body, context } = await valid();
  assert.deepEqual(
    validateClassWorkshopBody(body, withLookups(context, { subcategoryApplies: () => undefined })),
    ['class_workshop.taxonomy_unavailable'],
  );
  assert.deepEqual(
    validateClassWorkshopBody(body, withLookups(context, { requiredCriteria: () => undefined })),
    ['class_workshop.criteria_registry_unavailable'],
  );
  assert.deepEqual(
    validateClassWorkshopBody(body, withLookups(context, { supportsLocale: () => undefined })),
    ['class_workshop.locale_unavailable', 'class_workshop_media_incomplete'],
  );
  assert.deepEqual(
    validateClassWorkshopBody(body, withLookups(context, { pointInServiceArea: () => undefined })),
    ['class_workshop.service_area_unavailable'],
  );
});

void test('only the personal publisher in LV is eligible; page or foreign author refuse', async () => {
  const { body, context } = await valid();
  assert.deepEqual(
    validateClassWorkshopBody(body, {
      ...context,
      publisherRef: { type: 'page', id: owner as never },
    }),
    ['class_workshop_publisher_ineligible'],
  );
  assert.deepEqual(
    validateClassWorkshopBody(body, {
      ...context,
      createdByUserId: '22222222-2222-4222-8222-222222222222',
    }),
    ['class_workshop_publisher_ineligible'],
  );
  assert.deepEqual(validateClassWorkshopBody(body, { ...context, marketId: 'EE' }), [
    'class_workshop.market',
  ]);
});

void test('submit/publish need every class ahead; activation needs at least one', async () => {
  const { body, context } = await valid();
  const data = body.class_workshop as {
    occurrences: Record<string, unknown>[];
    context_kind: string;
  };
  data.context_kind = 'fixed_series';
  data.occurrences.push({
    id: '44444444-4444-4444-8444-444444444402',
    local_date: '2027-05-22',
    start_minute_local: 600,
    end_minute_local: 780,
    start_at_utc: '2027-05-22T07:00:00.000Z',
    end_at_utc: '2027-05-22T10:00:00.000Z',
  });
  // Between the two classes: one has started, one is ahead.
  const between = '2027-05-18T00:00:00.000Z';
  assert.deepEqual(validateClassWorkshopBody(body, { ...context, nowUtc: between }), []);
  assert.deepEqual(classWorkshopPastOccurrenceIssues(body, between), [
    'class_workshop_occurrence_in_past',
  ]);
  assert.deepEqual(classWorkshopPastOccurrenceIssues(body, context.nowUtc), []);
  const after = '2027-06-01T00:00:00.000Z';
  assert.deepEqual(validateClassWorkshopBody(body, { ...context, nowUtc: after }), [
    'class_workshop_no_future_occurrence',
  ]);
  assert.deepEqual(classWorkshopPastOccurrenceIssues({}, after), ['class_workshop.payload']);
});

void test('end of day 24:00 resolves to the next local midnight', async () => {
  const { body, context } = await valid();
  const occurrence = (body.class_workshop as { occurrences: Record<string, unknown>[] })
    .occurrences[0]!;
  Object.assign(occurrence, {
    start_minute_local: 1200,
    end_minute_local: 1440,
    start_at_utc: '2027-05-15T17:00:00.000Z',
    end_at_utc: '2027-05-15T21:00:00.000Z',
  });
  assert.deepEqual(validateClassWorkshopBody(body, context), []);
});

void test('a series of exactly sixty classes is accepted and sixty-one is refused', async () => {
  const { body, context } = await valid();
  const data = body.class_workshop as {
    occurrences: Record<string, unknown>[];
    context_kind: string;
    price: Record<string, unknown>;
  };
  data.context_kind = 'fixed_series';
  const series = (count: number) =>
    Array.from({ length: count }, (_, index) => {
      const day = new Date(Date.UTC(2027, 4, 1 + index));
      const date = day.toISOString().slice(0, 10);
      return {
        id: `77777777-7777-4777-8777-${String(index).padStart(12, '0')}`,
        local_date: date,
        start_minute_local: 600,
        end_minute_local: 660,
        start_at_utc: `${date}T07:00:00.000Z`,
        end_at_utc: `${date}T08:00:00.000Z`,
      };
    });
  data.price.scope = 'per_person_full_series';
  data.occurrences = series(60);
  assert.deepEqual(validateClassWorkshopBody(body, context), []);
  data.occurrences = series(61);
  assert.deepEqual(validateClassWorkshopBody(body, context), ['class_workshop_context_count']);
});

void test('Class rules never borrow Session weekly rules or Event archetype fields', async () => {
  const { body, context } = await valid();
  const data = body.class_workshop as Record<string, unknown>;
  for (const [key, value] of [
    ['weekly_rules', []],
    ['archetype', 'workshop'],
    ['admission', 'openEntry'],
    ['capacity', 8],
    ['recurrence', { frequency: 'weekly' }],
  ] as const) {
    const changed = structuredClone(body);
    (changed.class_workshop as Record<string, unknown>)[key] = value;
    assert.deepEqual(validateClassWorkshopBody(changed, context), [
      `class_workshop.payload.unknown_field:${key}`,
    ]);
  }
  assert.equal(data.schema_version, 1);
});

void test('media ids are the cover and gallery in order', async () => {
  const { body } = await valid();
  (body.media as { gallery: unknown[] }).gallery = [
    { mediaId: '88888888-8888-4888-8888-888888888888', altText: { en: 'x' } },
  ];
  assert.deepEqual(classWorkshopMediaIds(body), [
    '33333333-3333-4333-8333-333333333333',
    '88888888-8888-4888-8888-888888888888',
  ]);
  assert.deepEqual(classWorkshopMediaIds({}), []);
});
