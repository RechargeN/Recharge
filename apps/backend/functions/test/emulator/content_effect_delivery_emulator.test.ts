import assert from 'node:assert/strict';
import { after, test } from 'node:test';

import {
  catalogEffectConsumer,
  deliverContentEffects,
  type ContentEffectConsumer,
} from '../../src/content_effects_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { catalogFlagIds } from '../../src/shared/feature_flags.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { createContentEventWorld } from '../support/content_event_world.js';

const firestore = emulatorFirestore();
const world = createContentEventWorld(firestore, 'e2a-delivery');
const catalog = createEmulatorCatalogComposition(firestore);
const query = { schemaVersion: 1, marketId: 'LV', subcategoryIds: [world.subcategory] };

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

const probeFlag = 'test.e2a.probe';
const enabled =
  (...ids: string[]) =>
  (id: string) =>
    Promise.resolve(ids.includes(id));

/** A second consumer with its own position; `broken` makes every run throw. */
function probeConsumer(state: { broken: boolean; runs: number }): ContentEffectConsumer {
  return {
    name: 'probe',
    flagId: probeFlag,
    run() {
      state.runs += 1;
      if (state.broken) return Promise.reject(new TypeError('probe_down'));
      return Promise.resolve({ status: 'completed' });
    },
  };
}

async function listed(): Promise<readonly string[]> {
  const page = await catalog.query.feed({ query });
  if (page.kind !== 'succeeded') return [];
  return page.items.map((item) => item.ref.contentId);
}

void test('flags default off: no consumer runs and nothing is projected', async () => {
  await world.publish({ title: 'Silent workshop', date: '2035-10-12' });
  const state = { broken: false, runs: 0 };
  const outcomes = await deliverContentEffects(firestore, {
    flags: { isEnabled: enabled() },
    consumers: [catalogEffectConsumer(), probeConsumer(state)],
  });
  assert.deepEqual(outcomes, [
    { consumer: 'catalog', status: 'disabled' },
    { consumer: 'probe', status: 'disabled' },
  ]);
  assert.equal(state.runs, 0);
  const pointer = await firestore.collection(catalogCollections.active).get();
  assert.equal(pointer.size, 0, 'the Catalog was never initialized');
});

void test('a failing consumer neither blocks nor marks the Catalog, and resumes on its own', async () => {
  const contentId = await world.publish({ title: 'Loud workshop', date: '2035-10-13' });
  const state = { broken: true, runs: 0 };
  // The broken consumer runs first: the Catalog still completes after it.
  const first = await deliverContentEffects(firestore, {
    flags: { isEnabled: enabled(catalogFlagIds.delivery, probeFlag) },
    consumers: [probeConsumer(state), catalogEffectConsumer()],
  });
  assert.deepEqual(first, [
    { consumer: 'probe', status: 'failed', detail: 'TypeError' },
    { consumer: 'catalog', status: 'completed' },
  ]);
  assert.ok((await listed()).includes(contentId));

  // No new Content effect: the failure is still resumed by the next run.
  state.broken = false;
  const second = await deliverContentEffects(firestore, {
    flags: { isEnabled: enabled(catalogFlagIds.delivery, probeFlag) },
    consumers: [probeConsumer(state), catalogEffectConsumer()],
  });
  assert.deepEqual(second, [
    { consumer: 'probe', status: 'completed' },
    { consumer: 'catalog', status: 'completed' },
  ]);
  assert.equal(state.runs, 2);
  const active = await catalog.sets.ensureActive();
  assert.equal((await catalog.projector.deliverFromContent(active.setId)).processed, 0);
});

void test('an unreadable flag fails only its own consumer', async () => {
  const outcomes = await deliverContentEffects(firestore, {
    flags: {
      isEnabled: (id) =>
        id === probeFlag
          ? Promise.reject(new RangeError('flag_store_down'))
          : Promise.resolve(id === catalogFlagIds.delivery),
    },
    consumers: [probeConsumer({ broken: false, runs: 0 }), catalogEffectConsumer()],
  });
  assert.deepEqual(outcomes, [
    { consumer: 'probe', status: 'failed', detail: 'RangeError' },
    { consumer: 'catalog', status: 'completed' },
  ]);
});
