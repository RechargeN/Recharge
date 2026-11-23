import assert from 'node:assert/strict';
import test from 'node:test';

import { deleteApp, initializeApp } from 'firebase-admin/app';
import type { Firestore } from 'firebase-admin/firestore';

import { handleDiscoverQuery } from '../../src/catalog_entry.js';
import { scenarioStopsFor } from '../../src/content_entry.js';
import {
  createDevContentMedia,
  limitDiscoverRequest,
  pilotCatalogLimits,
  pilotDiscoverCaller,
} from '../../src/dev_content_media_composition.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { ContentPersistenceEnvironmentError } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { FirestoreRouteRevisionReader } from '../../src/modules/route/route_publication.js';

// The pilot defects of 2026-11-22 all passed local tests and failed only in the
// deployed environment, so these build the real compositions in exactly that one.
const projectId = 'recharge-dev-n2a01';
const cloud = {
  GCLOUD_PROJECT: projectId,
  RECHARGE_DEV_RUNTIME: 'content-media',
  RECHARGE_MEDIA_STORAGE: 'dev-cloud',
  RECHARGE_MEDIA_TOOLS: 'dev-cloud',
  RECHARGE_MEDIA_TOOLS_TOKEN: 'a'.repeat(64),
};
const client = { projectId, _settings: {} } as unknown as Firestore;

void test('cloud Catalog starts without Find People and refuses to start with it', () => {
  assert.doesNotThrow(() => createEmulatorCatalogComposition(client, { environment: cloud }));
  // OD-11: Find People has no cloud authority, so switching it on fails closed.
  assert.throws(
    () => createEmulatorCatalogComposition(client, { environment: cloud, findPeopleEnabled: true }),
    ContentPersistenceEnvironmentError,
  );
});

async function inCloud(run: () => unknown): Promise<void> {
  const previous = { ...process.env };
  try {
    for (const name of ['FIRESTORE_EMULATOR_HOST', 'FUNCTIONS_EMULATOR'])
      Reflect.deleteProperty(process.env, name);
    Object.assign(process.env, cloud);
    await run();
  } finally {
    for (const name of Object.keys(process.env))
      if (!(name in previous)) Reflect.deleteProperty(process.env, name);
    Object.assign(process.env, previous);
  }
}

void test('cloud Scenario gets its Catalog stop reader', () =>
  inCloud(() => assert.doesNotThrow(() => scenarioStopsFor(client))));

void test('cloud Content verifies a Route revision through the Route reader', async () => {
  const app = initializeApp({ projectId }, 'pilot-cloud-compositions');
  try {
    const { content } = createDevContentMedia({
      app,
      firestore: client,
      environment: cloud,
      idToken: () => Promise.resolve('test-id-token'),
    });
    const { deps } = content as unknown as { deps: { routeRevisions?: unknown } };
    assert.ok(deps.routeRevisions instanceof FirestoreRouteRevisionReader);
  } finally {
    await deleteApp(app);
  }
});

void test('cloud Discover is fresh for five minutes and stale after', () =>
  inCloud(async () => {
    const freshnessAfter = async (seconds: number) => {
      const set = {
        setId: 'set-1',
        revision: 1,
        lastSourceSyncAtUtc: new Date(Date.now() - seconds * 1000).toISOString(),
      };
      const noItems = {
        where: () => noItems,
        limit: () => noItems,
        get: () => Promise.resolve({ docs: [] }),
      };
      const firestore = {
        projectId,
        _settings: {},
        runTransaction: () => Promise.resolve(set),
        collection: () => noItems,
      } as unknown as Firestore;
      const answer = await handleDiscoverQuery(pilotDiscoverCaller(firestore, 'viewer-1'), {
        schemaVersion: 1,
        queryType: 'feed',
        requestId: 'freshness',
        payload: { query: { schemaVersion: 1, marketId: 'LV' } },
      });
      return /"projection":"(\w+)"/u.exec(JSON.stringify(answer))?.[1] ?? JSON.stringify(answer);
    };
    assert.equal(await freshnessAfter(290), 'fresh');
    assert.equal(await freshnessAfter(310), 'stale');
  }));

void test('candidate lists are capped at the pilot page', () => {
  for (const queryType of ['placeCandidates', 'publishedObjectCandidates']) {
    const request = (limit: number) => ({ queryType, payload: { marketId: 'LV', limit } });
    assert.deepEqual(limitDiscoverRequest(request(50)), {
      data: request(pilotCatalogLimits.pageSizeMax),
    });
    assert.deepEqual(limitDiscoverRequest(request(7)), { data: request(7) });
    // An invalid limit stays invalid for the handler instead of becoming valid.
    assert.deepEqual(limitDiscoverRequest(request(51)), { data: request(51) });
  }
});
