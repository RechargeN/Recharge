// D3.7 (FIND_PEOPLE / T3): the private source rule, the server-built public
// projection and the published-body rule, against the shared wire fixture.
import assert from 'node:assert/strict';
import test from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import {
  findPeopleHostUserId,
  findPeopleMeetingEnd,
  findPeoplePublicBody,
  hasFindPeopleExactLocation,
  validateFindPeopleBody,
  validateFindPeoplePublishedBody,
  withoutFindPeopleExactLocation,
} from '../../../src/modules/content/domain/type_rules/find_people_rules.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import {
  containsCoordinatePair,
  findPeoplePolicy,
  isPublicCellCentre,
  publicCellCentre,
} from '../../../src/shared/find_people_policy.js';
import { distanceMeters } from '../../../src/modules/catalog/domain/evaluation.js';

interface Fixture {
  readonly serverOwnerUserId: string;
  readonly nowUtc: string;
  readonly cases: readonly {
    readonly name: string;
    readonly body: ContentBody;
    readonly expectedIssues: readonly string[];
  }[];
}

async function setup() {
  const fixture = (await readContentJson('fixtures/find_people_create_compat.json')) as Fixture;
  const ref = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'find_people',
  });
  assert.ok(ref.ok);
  const context: ContentValidationContext = {
    typeId: 'find_people',
    marketId: 'LV',
    publisherRef: { type: 'user', id: fixture.serverOwnerUserId as never },
    createdByUserId: fixture.serverOwnerUserId,
    actorUserId: fixture.serverOwnerUserId,
    nowUtc: fixture.nowUtc,
    draftRevision: 1,
    market: ref.market,
    lookups: ref.lookups,
  };
  const valid = fixture.cases.find((item) => item.name === 'valid')!.body;
  const policy = ref.lookups.findPeoplePublicGeo?.();
  assert.ok(policy);
  return { fixture, context, valid, policy };
}

void test('shared wire fixture: the valid body passes and every variant fails exactly as recorded', async () => {
  const { fixture, context } = await setup();
  assert.ok(fixture.cases.length >= 20);
  for (const item of fixture.cases)
    assert.deepEqual(validateFindPeopleBody(item.body, context), item.expectedIssues, item.name);
});

void test('publisher: a personal request belongs to its author; a Page publisher is left to Identity', async () => {
  const { context, valid } = await setup();
  assert.deepEqual(
    validateFindPeopleBody(valid, {
      ...context,
      publisherRef: { type: 'user', id: '22222222-2222-4222-8222-222222222222' as never },
    }),
    ['find_people.publisher_ineligible'],
  );
  assert.deepEqual(
    validateFindPeopleBody(valid, {
      ...context,
      publisherRef: { type: 'page', id: '33333333-3333-4333-8333-333333333333' as never },
    }),
    [],
  );
  assert.deepEqual(validateFindPeopleBody(valid, { ...context, marketId: 'EE' }), [
    'find_people.market',
  ]);
});

void test('reference policy unavailable fails closed instead of a default precision', async () => {
  const { context, valid } = await setup();
  const lookups = { ...context.lookups };
  delete (lookups as { findPeoplePublicGeo?: unknown }).findPeoplePublicGeo;
  assert.deepEqual(validateFindPeopleBody(valid, { ...context, lookups }), [
    'find_people.geo_policy_unavailable',
  ]);
});

void test('public projection: built field by field, no private data, server-computed cell centre', async () => {
  const { context, valid, policy } = await setup();
  const exact = (valid.findPeople as { meeting: { exact: Record<string, unknown> } }).meeting.exact;
  const published = findPeoplePublicBody(valid, policy);
  const text = JSON.stringify(published);
  for (const secret of [
    String(exact.latitude),
    String(exact.longitude),
    String(exact.placeName),
    String(exact.addressLine),
    String(exact.instructions),
  ])
    assert.equal(text.includes(secret), false, secret);
  for (const key of [
    'exact',
    'confirmations',
    'quietHoursStartMinute',
    'revision',
    'publicPlaceConfirmed',
  ])
    assert.equal(text.includes(`"${key}"`), false, key);
  const location = (published.findPeople as { meeting: { publicLocation: Record<string, number> } })
    .meeting.publicLocation;
  assert.equal(location.precisionMeters, findPeoplePolicy.publicGeoPrecisionMeters);
  assert.ok(isPublicCellCentre(location.latitude!, location.longitude!));
  assert.notEqual(location.latitude, exact.latitude);
  const offset = distanceMeters(
    { latitude: exact.latitude as number, longitude: exact.longitude as number },
    { latitude: location.latitude!, longitude: location.longitude! },
  );
  assert.ok(offset > 0 && offset <= 720, `offset ${offset}`);
  // Deterministic, never a random jitter per read.
  assert.deepEqual(findPeoplePublicBody(valid, policy), published);
  // The published rule accepts it; the source rule does not.
  assert.deepEqual(validateFindPeoplePublishedBody(published, context), []);
  assert.ok(validateFindPeopleBody(published, context).length > 0);
  assert.ok(validateFindPeoplePublishedBody(valid, context).length > 0);
  assert.equal(findPeopleHostUserId(published), context.createdByUserId);
  assert.equal(findPeopleMeetingEnd(published), '2027-05-15T07:30:00.000Z');
});

void test('published rule refuses a smuggled exact point, an off-grid point or another policy', async () => {
  const { context, valid, policy } = await setup();
  const published = findPeoplePublicBody(valid, policy) as Record<string, unknown>;
  const withMeeting = (change: (meeting: Record<string, unknown>) => void) => {
    const body = structuredClone(published) as { findPeople: { meeting: Record<string, unknown> } };
    change(body.findPeople.meeting);
    return validateFindPeoplePublishedBody(body, context);
  };
  assert.ok(
    withMeeting((m) => (m.exact = { latitude: 56.95182, longitude: 24.08571 })).includes(
      'find_people.meeting.unknown_field:exact',
    ),
  );
  assert.deepEqual(
    withMeeting((m) => ((m.publicLocation as Record<string, number>).latitude = 56.95182)),
    ['find_people.public_location'],
  );
  assert.deepEqual(
    withMeeting((m) => ((m.publicLocation as Record<string, number>).precisionMeters = 100)),
    ['find_people.public_location'],
  );
  assert.deepEqual(
    withMeeting(
      (m) => ((m.publicLocation as Record<string, unknown>).policyRevision = 'another-policy'),
    ),
    ['find_people.public_location'],
  );
});

void test('cell centre is idempotent, stays inside the cell and is stable across the cell', () => {
  for (const [lat, lng] of [
    [56.9496, 24.1052],
    [56.95182, 24.08571],
    [57.3901, 21.5643],
    [55.8807, 26.5361],
  ] as const) {
    const centre = publicCellCentre(lat, lng);
    assert.deepEqual(publicCellCentre(centre.latitude, centre.longitude), centre);
    assert.ok(isPublicCellCentre(centre.latitude, centre.longitude));
    assert.ok(distanceMeters({ latitude: lat, longitude: lng }, centre) <= 720);
    // Any point between the source and the centre is in the same cell: same centre.
    const near = publicCellCentre(
      lat + (centre.latitude - lat) / 2,
      lng + (centre.longitude - lng) / 2,
    );
    assert.deepEqual(near, centre);
  }
  assert.equal(isPublicCellCentre(56.95182, 24.08571), false);
});

void test('coordinate pairs in public text are detected, ordinary numbers are not', () => {
  assert.equal(containsCoordinatePair('Meet at 56.95182, 24.08571'), true);
  assert.equal(containsCoordinatePair('56,9518 / 24,0857'), true);
  assert.equal(containsCoordinatePair('Easy 8 km jog, 2 laps of 4.5 km'), false);
  assert.equal(containsCoordinatePair('Start 10:30, finish 12:00'), false);
});

void test('retention helpers remove exactly the private meeting data', async () => {
  const { valid } = await setup();
  assert.equal(hasFindPeopleExactLocation(valid), true);
  const erased = withoutFindPeopleExactLocation(valid);
  assert.equal(hasFindPeopleExactLocation(erased), false);
  const keep = structuredClone(valid) as { findPeople: { meeting: Record<string, unknown> } };
  delete keep.findPeople.meeting.exact;
  assert.deepEqual(erased, keep);
  // The input is not mutated.
  assert.equal(hasFindPeopleExactLocation(valid), true);
});
