import assert from 'node:assert/strict';
import { after, test } from 'node:test';

import { handleDiscoverQuery } from '../../src/catalog_entry.js';
import { catalogEffectConsumer, deliverContentEffects } from '../../src/content_effects_entry.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { catalogFlagIds } from '../../src/shared/feature_flags.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createContentEventWorld } from '../support/content_event_world.js';

const firestore = emulatorFirestore();
const world = createContentEventWorld(firestore, 'e2a');
const query = { schemaVersion: 1, marketId: 'LV', subcategoryIds: [world.subcategory] };
// Flags come from memory, never from Firestore: the Functions Emulator trigger
// stays disabled and cannot race this test.
const deliver = () =>
  deliverContentEffects(firestore, {
    flags: { isEnabled: (id) => Promise.resolve(id === catalogFlagIds.delivery) },
    consumers: [catalogEffectConsumer()],
  });

after(async () => {
  for (const name of [
    ...Object.values(catalogCollections),
    ...Object.values(contentCollections),
    ...Object.values(mediaCollections),
    ...Object.values(moderationCollections),
  ]) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
});

let sequence = 0;
async function discover(
  queryType: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const result = await handleDiscoverQuery(
    { firestore },
    {
      schemaVersion: 1,
      requestId: `e2a-${(sequence += 1)}`,
      queryType,
      payload,
      // The mobile transport always adds the Session; the handler ignores it.
      sessionContext: { sessionId: 'ignored', sessionHandle: 'ignored', installationId: 'x' },
    },
  );
  return result;
}

interface Card {
  readonly ref: { readonly contentId: string };
  readonly publishedRevisionId: string;
}

void test('Feed, Search, Map and Details read one snapshot; hidden content leaves all of them', async () => {
  const first = await world.publish({ title: 'Clay night by the river', date: '2035-10-10' });
  const second = await world.publish({ title: 'Glass blowing open day', date: '2035-10-11' });
  const outcomes = await deliver();
  assert.deepEqual(outcomes, [{ consumer: 'catalog', status: 'completed' }]);

  const feed = await discover('feed', { query });
  assert.equal(feed.kind, 'succeeded', JSON.stringify(feed));
  const page = feed.page as {
    snapshotToken: string;
    projectionSetRevision: number;
    items: Card[];
  };
  const cards = new Map(page.items.map((card) => [card.ref.contentId, card]));
  assert.deepEqual([...cards.keys()].sort(), [first, second].sort());
  assert.equal(
    JSON.stringify(page.items).includes('fullDescription'),
    false,
    'cards never carry the full description',
  );

  const search = await discover('search', {
    query: { ...query, literalText: 'clay river' },
  });
  assert.equal(search.kind, 'succeeded', JSON.stringify(search));
  assert.deepEqual(
    (search.page as { items: Card[] }).items.map((card) => card.ref.contentId),
    [first],
  );

  const map = await discover('map', { query, snapshotToken: page.snapshotToken });
  assert.equal(map.kind, 'succeeded', JSON.stringify(map));
  const leaves = map.map as {
    projectionSetRevision: number;
    leaves: { ref: { contentId: string } }[];
  };
  assert.equal(leaves.projectionSetRevision, page.projectionSetRevision, 'same snapshot');
  assert.deepEqual(leaves.leaves.map((leaf) => leaf.ref.contentId).sort(), [first, second].sort());

  const details = await discover('details', {
    contentId: first,
    snapshotToken: page.snapshotToken,
    query,
  });
  assert.equal(details.kind, 'succeeded', JSON.stringify(details));
  const body = details.details as {
    state: string;
    changedSinceSnapshot: boolean;
    item: { publishedRevisionId: string; fullDescription: string };
  };
  assert.equal(body.state, 'listed');
  assert.equal(body.changedSinceSnapshot, false);
  assert.equal(
    body.item.publishedRevisionId,
    cards.get(first)?.publishedRevisionId,
    'same revision',
  );
  assert.ok(body.item.fullDescription.length > 0);

  await world.ownerWithdraw(first);
  assert.deepEqual(await deliver(), [{ consumer: 'catalog', status: 'completed' }]);
  const after = await discover('feed', { query });
  assert.deepEqual(
    (after.page as { items: Card[] }).items.map((card) => card.ref.contentId),
    [second],
  );
  const afterMap = await discover('map', { query });
  assert.deepEqual(
    (afterMap.map as { leaves: { ref: { contentId: string } }[] }).leaves.map(
      (leaf) => leaf.ref.contentId,
    ),
    [second],
  );
  const hidden = await discover('details', {
    contentId: first,
    snapshotToken: page.snapshotToken,
    query,
  });
  const hiddenBody = hidden.details as {
    state: string;
    reason: string;
    item: unknown;
    changedSinceSnapshot: boolean;
  };
  assert.deepEqual(
    [hiddenBody.state, hiddenBody.reason, hiddenBody.item, hiddenBody.changedSinceSnapshot],
    ['excluded', 'withdrawn', null, true],
  );
});

void test('the envelope refuses malformed requests by name', async () => {
  const refuse = async (data: unknown) => {
    const result = (await handleDiscoverQuery({ firestore }, data)) as {
      kind: string;
      code: string;
    };
    return `${result.kind}:${result.code}`;
  };
  assert.equal(await refuse(null), 'rejected:invalid_request');
  assert.equal(
    await refuse({ schemaVersion: 2, requestId: 'r', queryType: 'feed', payload: { query } }),
    'unsupported:unsupported_version',
  );
  assert.equal(
    await refuse({ schemaVersion: 1, requestId: 'r', queryType: 'nearby', payload: {} }),
    'unsupported:query_type_unsupported',
  );
  assert.equal(
    await refuse({ schemaVersion: 1, requestId: 'r', queryType: 'feed', payload: { query, x: 1 } }),
    'unsupported:unknown_field:x',
  );
  assert.equal(
    await refuse({
      schemaVersion: 1,
      requestId: 'r',
      queryType: 'feed',
      payload: { query: { ...query, onlyAvailable: true } },
    }),
    'unsupported:booking_availability_source_not_connected_in_e1',
  );
});
