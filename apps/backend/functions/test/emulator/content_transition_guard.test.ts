import assert from 'node:assert/strict';
import { after, test } from 'node:test';

import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createContentEventWorld } from '../support/content_event_world.js';

const firestore = emulatorFirestore();
const world = createContentEventWorld(firestore, 'e20-transition');

after(async () => {
  for (const name of [
    ...Object.values(contentCollections),
    ...Object.values(mediaCollections),
    ...Object.values(moderationCollections),
  ]) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
});

type Body = Record<string, unknown>;
const internal =
  (participants: Body = { capacityMode: 'known', capacity: 20 }, location?: Body) =>
  (body: Body): Body => ({
    ...body,
    participants,
    ...(location === undefined ? {} : { location: { ...(body.location as Body), ...location } }),
    registration: {
      mode: 'internal',
      confirmationMode: 'instant',
      maxPartySize: 2,
      opensMinutesBeforeStart: 525_600,
      closesMinutesBeforeStart: 60,
      cancellationClosesMinutesBeforeStart: 120,
    },
  });

void test('a published internal Event keeps its mode, capacity mode and venue; rollback included', async () => {
  const contentId = await world.publish({ title: 'Wheel night', date: '2035-10-10' });
  const first = (await world.pointer(contentId)).currentPublishedRevisionId;
  assert.ok(first);

  // none → internal is a new projection: allowed.
  assert.deepEqual(
    await world.revise(contentId, {
      title: 'Wheel night',
      date: '2035-10-10',
      transform: internal(),
    }),
    { stage: 'publish', kind: 'succeeded' },
  );
  const second = (await world.pointer(contentId)).currentPublishedRevisionId;
  assert.notEqual(second, first);

  const refused = { stage: 'submit', kind: 'rejected', code: 'validation_failed' };
  assert.deepEqual(
    await world.revise(contentId, { title: 'Wheel night', date: '2035-10-10' }),
    refused,
    'internal → none',
  );
  assert.deepEqual(
    await world.revise(contentId, {
      title: 'Wheel night',
      date: '2035-10-10',
      transform: internal({ capacityMode: 'unlimited' }),
    }),
    refused,
    'finite → unlimited',
  );
  assert.deepEqual(
    await world.revise(contentId, {
      title: 'Wheel night',
      date: '2035-10-10',
      transform: internal(undefined, { formattedAddress: 'Elsewhere 2, Riga' }),
    }),
    refused,
    'venue change',
  );

  // Capacity and time may change through the Booking lifecycle.
  assert.deepEqual(
    await world.revise(contentId, {
      title: 'Wheel night',
      date: '2035-10-11',
      transform: internal({ capacityMode: 'known', capacity: 8 }),
    }),
    { stage: 'publish', kind: 'succeeded' },
  );

  // A rollback to the revision without internal registration is a pointer
  // switch too: refused in the switching transaction, the pointer unchanged.
  const before = await world.pointer(contentId);
  assert.deepEqual(await world.activate(contentId, first), {
    stage: 'activate',
    kind: 'rejected',
    code: 'validation_failed',
  });
  const afterRefusal = await world.pointer(contentId);
  assert.equal(afterRefusal.revision, before.revision);
  assert.equal(afterRefusal.currentPublishedRevisionId, before.currentPublishedRevisionId);

  // Rolling back to the earlier internal revision is allowed.
  assert.ok(second);
  assert.deepEqual(await world.activate(contentId, second), {
    stage: 'activate',
    kind: 'succeeded',
  });
});
