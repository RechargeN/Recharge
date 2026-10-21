// D3.1 §2.1 (PLACE_D3_1_PUBLICATION_AMENDMENT.md), D3.2 §2.1
// (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md), D3.3
// (RENTAL_D3_3_PUBLICATION_AMENDMENT.md) and D3.4 §2.1
// (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md): which authoring types the
// Emulator path may enable, and that a type outside the list or without a
// validator can never be enabled. Pure functions only; the service behaviour is
// in test/integration/content_place_enablement.test.ts,
// test/integration/content_activity_enablement.test.ts,
// test/integration/content_rental_enablement.test.ts and
// test/integration/content_collection_enablement.test.ts.
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertEmulatorAuthoringTypes,
  authoringTypesFor,
  emulatorAuthoringTypes,
} from '../../../src/content_entry.js';
import { contentTypeIds } from '../../../src/contracts/content_v1.js';
import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';

void test('each authoring flag enables exactly its own type', () => {
  const sorted = (set: ReadonlySet<string>) => [...set].sort();
  for (const eventAuthoring of [false, true])
    for (const placeAuthoring of [false, true])
      for (const activityAuthoring of [false, true])
        for (const rentalAuthoring of [false, true])
          for (const collectionAuthoring of [false, true])
            assert.deepEqual(
              sorted(
                authoringTypesFor({
                  eventAuthoring,
                  placeAuthoring,
                  activityAuthoring,
                  rentalAuthoring,
                  collectionAuthoring,
                }),
              ),
              [
                ...(activityAuthoring ? ['activity'] : []),
                ...(collectionAuthoring ? ['collection'] : []),
                ...(eventAuthoring ? ['event'] : []),
                ...(placeAuthoring ? ['place'] : []),
                ...(rentalAuthoring ? ['rental'] : []),
              ],
            );
  // The Collection flag is optional for callers that predate D3.4: absent means off.
  assert.deepEqual(
    sorted(
      authoringTypesFor({
        eventAuthoring: true,
        placeAuthoring: true,
        activityAuthoring: true,
        rentalAuthoring: true,
      }),
    ),
    ['activity', 'event', 'place', 'rental'],
  );
});

void test('the Emulator authoring list is Event, Place, Activity, Rental and Collection, each with an available validator', () => {
  assert.deepEqual(
    [...emulatorAuthoringTypes],
    [
      'event',
      'place',
      'activity',
      'rental',
      'collection',
      'session',
      'scenario',
      'class_workshop',
      'find_people',
    ],
  );
  for (const typeId of emulatorAuthoringTypes) {
    const entry = resolveContentType(typeId);
    assert.ok(entry !== null && isContentTypeAvailable(entry), typeId);
  }
  assert.doesNotThrow(() => assertEmulatorAuthoringTypes(new Set()));
  assert.doesNotThrow(() =>
    assertEmulatorAuthoringTypes(
      new Set([
        'event',
        'place',
        'activity',
        'rental',
        'collection',
        'session',
        'scenario',
        'class_workshop',
        'find_people',
      ]),
    ),
  );
});

void test('no other type can be enabled, with or without a validator', () => {
  const others = contentTypeIds.filter((typeId) => !emulatorAuthoringTypes.includes(typeId));
  assert.deepEqual(others, ['route']);
  for (const typeId of others) {
    assert.throws(
      () => assertEmulatorAuthoringTypes(new Set(['collection', typeId])),
      new RegExp(`content_authoring_type_not_allowed:${typeId}$`),
    );
  }
  // Types without a validator are unavailable in the registry as well.
  for (const typeId of ['route'] as const) {
    const entry = resolveContentType(typeId);
    assert.ok(entry !== null && !isContentTypeAvailable(entry));
  }
  assert.throws(
    () => assertEmulatorAuthoringTypes(new Set(['unknown_type'])),
    /content_authoring_type_not_allowed:unknown_type$/,
  );
});

void test('I3 Scenario flag is independent and absent means off', () => {
  const flags = {
    eventAuthoring: false,
    placeAuthoring: false,
    activityAuthoring: false,
    rentalAuthoring: false,
  };
  assert.deepEqual([...authoringTypesFor(flags)], []);
  assert.deepEqual([...authoringTypesFor({ ...flags, scenarioAuthoring: true })], ['scenario']);
  assert.doesNotThrow(() => assertEmulatorAuthoringTypes(new Set(['scenario'])));
});

void test('D3.5 Session flag is independent and absent means off', () => {
  const flags = {
    eventAuthoring: false,
    placeAuthoring: false,
    activityAuthoring: false,
    rentalAuthoring: false,
    collectionAuthoring: false,
  };
  assert.deepEqual([...authoringTypesFor(flags)], []);
  assert.deepEqual([...authoringTypesFor({ ...flags, sessionAuthoring: true })], ['session']);
  assert.doesNotThrow(() => assertEmulatorAuthoringTypes(new Set(['session'])));
});

void test('D3.6 Class flag is independent and absent means off', () => {
  const flags = {
    eventAuthoring: false,
    placeAuthoring: false,
    activityAuthoring: false,
    rentalAuthoring: false,
    collectionAuthoring: false,
    sessionAuthoring: true,
  };
  assert.deepEqual([...authoringTypesFor(flags)], ['session']);
  assert.deepEqual([...authoringTypesFor({ ...flags, sessionAuthoring: false })], []);
  assert.deepEqual(
    [...authoringTypesFor({ ...flags, sessionAuthoring: false, classWorkshopAuthoring: true })],
    ['class_workshop'],
  );
  assert.doesNotThrow(() => assertEmulatorAuthoringTypes(new Set(['class_workshop'])));
});

void test('D3.7 Find People flag is independent and absent means off', () => {
  const flags = {
    eventAuthoring: false,
    placeAuthoring: false,
    activityAuthoring: false,
    rentalAuthoring: false,
    collectionAuthoring: false,
    sessionAuthoring: false,
  };
  assert.deepEqual([...authoringTypesFor(flags)], []);
  assert.deepEqual(
    [...authoringTypesFor({ ...flags, findPeopleAuthoring: true })],
    ['find_people'],
  );
  assert.doesNotThrow(() => assertEmulatorAuthoringTypes(new Set(['find_people'])));
});
