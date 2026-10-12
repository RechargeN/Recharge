// D3.1 §2.1 (PLACE_D3_1_PUBLICATION_AMENDMENT.md), D3.2 §2.1
// (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md) and D3.3
// (RENTAL_D3_3_PUBLICATION_AMENDMENT.md): which authoring types the Emulator
// path may enable, and that a type outside the list or without a validator can
// never be enabled. Pure functions only; the service behaviour is in
// test/integration/content_place_enablement.test.ts and
// test/integration/content_activity_enablement.test.ts.
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
          assert.deepEqual(
            sorted(
              authoringTypesFor({
                eventAuthoring,
                placeAuthoring,
                activityAuthoring,
                rentalAuthoring,
              }),
            ),
            [
              ...(activityAuthoring ? ['activity'] : []),
              ...(eventAuthoring ? ['event'] : []),
              ...(placeAuthoring ? ['place'] : []),
              ...(rentalAuthoring ? ['rental'] : []),
            ],
          );
});

void test('the Emulator authoring list is Event, Place, Activity and Rental, each with an available validator', () => {
  assert.deepEqual([...emulatorAuthoringTypes], ['event', 'place', 'activity', 'rental']);
  for (const typeId of emulatorAuthoringTypes) {
    const entry = resolveContentType(typeId);
    assert.ok(entry !== null && isContentTypeAvailable(entry), typeId);
  }
  assert.doesNotThrow(() => assertEmulatorAuthoringTypes(new Set()));
  assert.doesNotThrow(() =>
    assertEmulatorAuthoringTypes(new Set(['event', 'place', 'activity', 'rental'])),
  );
});

void test('no other type can be enabled, with or without a validator', () => {
  const others = contentTypeIds.filter((typeId) => !emulatorAuthoringTypes.includes(typeId));
  assert.deepEqual(others.length, contentTypeIds.length - 4);
  for (const typeId of others) {
    assert.throws(
      () => assertEmulatorAuthoringTypes(new Set(['rental', typeId])),
      new RegExp(`content_authoring_type_not_allowed:${typeId}$`),
    );
  }
  // Collection has a validator and still stays off here.
  const collection = resolveContentType('collection');
  assert.ok(collection !== null && isContentTypeAvailable(collection));
  assert.ok(others.includes('collection'));
  // Types without a validator are unavailable in the registry as well.
  for (const typeId of ['route', 'session', 'scenario', 'find_people', 'class_workshop'] as const) {
    const entry = resolveContentType(typeId);
    assert.ok(entry !== null && !isContentTypeAvailable(entry));
  }
  assert.throws(
    () => assertEmulatorAuthoringTypes(new Set(['unknown_type'])),
    /content_authoring_type_not_allowed:unknown_type$/,
  );
});
