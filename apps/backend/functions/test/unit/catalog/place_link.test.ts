import assert from 'node:assert/strict';
import { test } from 'node:test';
import { PlaceLinkService } from '../../../src/modules/catalog/application/place_link_service.js';
import type {
  ContentCatalogSource,
  SourcePointer,
} from '../../../src/modules/catalog/application/ports.js';
import type { SourceRevision } from '../../../src/modules/catalog/domain/catalog_item.js';
let pointer: SourcePointer | null;
let revision: SourceRevision | null;
let offline = false,
  changing = false,
  reads = 0;
const source = {
  pointer: () => {
    if (offline) return Promise.reject(new Error('private storage detail'));
    if (changing && ++reads > 1 && pointer)
      return Promise.resolve({ ...pointer, revision: pointer.revision + 1 });
    return Promise.resolve(pointer);
  },
  publishedRevision: () => Promise.resolve(revision),
  typeVisibilityPolicy: () => 'public_catalog',
  pointersPage: () => Promise.resolve(pointer ? [pointer] : []),
} as unknown as ContentCatalogSource;
function reset() {
  offline = false;
  changing = false;
  reads = 0;
  pointer = {
    contentId: 'place',
    revision: 3,
    currentPublishedRevisionId: 'pub',
    visibility: 'visible',
  };
  revision = {
    contentId: 'place',
    publishedRevisionId: 'pub',
    typeId: 'place',
    marketId: 'LV',
    body: { title: 'Quiet Place' },
    referenceRevisions: {},
    publishedAtUtc: '2026-10-11T00:00:00Z',
  };
}
void test('Catalog owns exact current Place eligibility; hidden/wrong type/market/missing and disabled fail closed', async () => {
  reset();
  const service = new PlaceLinkService(source, true);
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'eligible',
    place: {
      contentId: 'place',
      publishedRevisionId: 'pub',
      pointerRevision: 3,
      marketId: 'LV',
      title: 'Quiet Place',
    },
  });
  assert.deepEqual(await new PlaceLinkService(source).check({ placeId: 'place', marketId: 'LV' }), {
    status: 'unavailable',
  });
  const absentPointerSource = { ...source, pointer: undefined } as unknown as ContentCatalogSource;
  assert.deepEqual(
    await new PlaceLinkService(absentPointerSource, true).check({
      placeId: 'place',
      marketId: 'LV',
    }),
    { status: 'unavailable' },
  );
  pointer = null;
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'unknown',
  });
  reset();
  pointer = { ...pointer!, visibility: 'restricted' };
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'forbidden',
  });
  for (const visibility of ['withdrawn', 'archived', 'restricted']) {
    reset();
    pointer = { ...pointer, visibility };
    assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
      status: 'forbidden',
    });
  }
  reset();
  pointer = { ...pointer, currentPublishedRevisionId: null };
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'forbidden',
  });
  for (const visibility of ['private', 'unlisted']) {
    reset();
    revision = { ...revision!, body: { title: 'Quiet Place', visibility } };
    assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
      status: 'forbidden',
    });
  }
  reset();
  revision = { ...revision!, typeId: 'event' };
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'forbidden',
  });
  reset();
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'EE' }), {
    status: 'forbidden',
  });
  reset();
  revision = null;
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'unavailable',
  });
  reset();
  offline = true;
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'unavailable',
  });
});
void test('candidate query remains bounded, current-eligible and paginated; source changes and outage are explicit', async () => {
  reset();
  const service = new PlaceLinkService(source, true);
  const page = await service.candidates({ marketId: 'LV', text: 'quiet', limit: 1 });
  assert.equal(page.status, 'available');
  if (page.status === 'available') {
    assert.equal(page.items.length, 1);
    assert.equal(page.nextCursor, 'place');
  }
  assert.deepEqual(await service.candidates({ marketId: 'LV', text: 'not a match', limit: 2 }), {
    status: 'available',
    items: [],
    nextCursor: null,
  });
  reset();
  changing = true;
  assert.deepEqual(await service.check({ placeId: 'place', marketId: 'LV' }), {
    status: 'unavailable',
  });
  reset();
  assert.deepEqual(await service.candidates({ marketId: 'LV', text: '', limit: 0 }), {
    status: 'unavailable',
  });
  offline = true;
  assert.deepEqual(await service.candidates({ marketId: 'LV', text: '', limit: 2 }), {
    status: 'unavailable',
  });
});
