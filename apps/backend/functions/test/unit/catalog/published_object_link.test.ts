// D3.4 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md §2.3): the one Catalog-owned
// exact-id evaluator of relations to published listings. Every listing type is
// asked by its own type; a hidden or restricted listing of the right type and
// market is `withheld` (never `eligible`), anything else is refused, and an
// outage or a pointer that moved between reads is `unavailable`. The D3.9
// Place relation keeps its answers (place_link.test.ts is unchanged).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { PlaceLinkService } from '../../../src/modules/catalog/application/place_link_service.js';
import { PublishedObjectLinkService } from '../../../src/modules/catalog/application/published_object_link_service.js';
import type {
  ContentCatalogSource,
  SourcePointer,
} from '../../../src/modules/catalog/application/ports.js';
import type { SourceRevision } from '../../../src/modules/catalog/domain/catalog_item.js';
import {
  isListingTypeId,
  listingTypeIds,
} from '../../../src/modules/catalog/domain/published_object_link.js';

interface World {
  pointers: Map<string, SourcePointer>;
  revisions: Map<string, SourceRevision>;
  offline: boolean;
  revisionReads: number;
  /** Moves the pointer after the first read of this id. */
  moving?: string;
}

function world(): World {
  return { pointers: new Map(), revisions: new Map(), offline: false, revisionReads: 0 };
}

function sourceOf(state: World, policy = 'public_catalog'): ContentCatalogSource {
  const reads = new Map<string, number>();
  return {
    pointer: (contentId: string) => {
      if (state.offline) return Promise.reject(new Error('private storage detail'));
      const count = (reads.get(contentId) ?? 0) + 1;
      reads.set(contentId, count);
      const pointer = state.pointers.get(contentId) ?? null;
      if (pointer !== null && state.moving === contentId && count > 1)
        return Promise.resolve({ ...pointer, revision: pointer.revision + 1 });
      return Promise.resolve(pointer);
    },
    publishedRevision: (id: string) => {
      state.revisionReads += 1;
      return Promise.resolve(state.revisions.get(id) ?? null);
    },
    typeVisibilityPolicy: () => policy,
    pointersPage: (after: string | null, limit: number) =>
      Promise.resolve(
        [...state.pointers.values()]
          .filter((pointer) => after === null || pointer.contentId > after)
          .sort((left, right) => (left.contentId < right.contentId ? -1 : 1))
          .slice(0, limit),
      ),
  } as unknown as ContentCatalogSource;
}

function publish(
  state: World,
  contentId: string,
  typeId: string,
  options: { visibility?: string; marketId?: string; body?: Record<string, unknown> } = {},
): void {
  const publishedRevisionId = `${contentId}-r1`;
  state.pointers.set(contentId, {
    contentId,
    revision: 2,
    currentPublishedRevisionId: publishedRevisionId,
    visibility: options.visibility ?? 'visible',
  });
  state.revisions.set(publishedRevisionId, {
    contentId,
    publishedRevisionId,
    typeId,
    marketId: options.marketId ?? 'LV',
    body: options.body ?? { title: `${typeId} ${contentId}` },
    referenceRevisions: {},
    publishedAtUtc: '2026-10-12T00:00:00Z',
  });
}

const ask = (service: PublishedObjectLinkService, typeId: string, contentId: string) =>
  service.status({ typeId: typeId as never, contentId, marketId: 'LV' });

void test('the listing types are exactly Place, Route, Session, Class/Workshop and Rental', () => {
  assert.deepEqual([...listingTypeIds], ['place', 'route', 'session', 'class_workshop', 'rental']);
  for (const typeId of listingTypeIds) assert.equal(isListingTypeId(typeId), true);
  for (const typeId of ['event', 'activity', 'scenario', 'find_people', 'collection', 'toString'])
    assert.equal(isListingTypeId(typeId), false, typeId);
  assert.equal(isListingTypeId(undefined), false);
});

void test('every listing type is eligible by its own type, with allowlisted public facts only', async () => {
  const state = world();
  for (const typeId of listingTypeIds) publish(state, `id-${typeId}`, typeId);
  const service = new PublishedObjectLinkService(sourceOf(state), true);
  for (const typeId of listingTypeIds)
    assert.deepEqual(await ask(service, typeId, `id-${typeId}`), {
      status: 'eligible',
      object: {
        typeId,
        contentId: `id-${typeId}`,
        publishedRevisionId: `id-${typeId}-r1`,
        pointerRevision: 2,
        marketId: 'LV',
        title: `${typeId} id-${typeId}`,
      },
    });
  // Asked as another listing type, the same id is refused.
  assert.deepEqual(await ask(service, 'rental', 'id-place'), { status: 'forbidden' });
  assert.deepEqual(await ask(service, 'place', 'id-rental'), { status: 'forbidden' });
});

void test('a hidden or restricted listing of the right type and market is withheld, without a title', async () => {
  for (const visibility of ['withdrawn', 'archived', 'restricted']) {
    const state = world();
    publish(state, 'hidden', 'place', { visibility });
    const service = new PublishedObjectLinkService(sourceOf(state), true);
    assert.deepEqual(await ask(service, 'place', 'hidden'), { status: 'withheld' }, visibility);
    // Withheld only for the exact type and market; otherwise it is refused.
    assert.deepEqual(await ask(service, 'rental', 'hidden'), { status: 'forbidden' });
    assert.deepEqual(
      await service.status({ typeId: 'place', contentId: 'hidden', marketId: 'EE' }),
      { status: 'forbidden' },
    );
    // Without `reportWithheld` (the D3.9 relation) it is forbidden before any revision read.
    const reads = state.revisionReads;
    assert.deepEqual(
      await service.status({ typeId: 'place', contentId: 'hidden', marketId: 'LV' }, false),
      { status: 'forbidden' },
    );
    assert.equal(state.revisionReads, reads);
  }
});

void test('unknown, non-public, wrong market and policy are refused; outage and moves are unavailable', async () => {
  const state = world();
  publish(state, 'event', 'event');
  publish(state, 'other-market', 'place', { marketId: 'EE' });
  publish(state, 'untitled', 'place', { body: { title: '  ' } });
  publish(state, 'unlisted', 'place', { body: { title: 'Quiet', visibility: 'unlisted' } });
  publish(state, 'moving', 'place');
  state.pointers.set('never-published', {
    contentId: 'never-published',
    revision: 1,
    currentPublishedRevisionId: null,
    visibility: 'visible',
  });
  state.pointers.set('dangling', {
    contentId: 'dangling',
    revision: 1,
    currentPublishedRevisionId: 'missing-revision',
    visibility: 'visible',
  });
  state.moving = 'moving';
  const service = new PublishedObjectLinkService(sourceOf(state), true);
  assert.deepEqual(await ask(service, 'place', 'absent'), { status: 'unknown' });
  for (const id of ['event', 'other-market', 'untitled', 'unlisted', 'never-published'])
    assert.deepEqual(await ask(service, 'place', id), { status: 'forbidden' }, id);
  assert.deepEqual(await ask(service, 'place', 'dangling'), { status: 'unavailable' });
  assert.deepEqual(await ask(service, 'place', 'moving'), { status: 'unavailable' });
  const consent = new PublishedObjectLinkService(sourceOf(state, 'consent_limited'), true);
  publish(state, 'consent', 'place');
  assert.deepEqual(await ask(consent, 'place', 'consent'), { status: 'forbidden' });
  state.offline = true;
  assert.deepEqual(await ask(service, 'place', 'event'), { status: 'unavailable' });
});

void test('disabled, or without the owner pointer read, every answer is unavailable', async () => {
  const state = world();
  publish(state, 'p', 'place');
  assert.deepEqual(await ask(new PublishedObjectLinkService(sourceOf(state)), 'place', 'p'), {
    status: 'unavailable',
  });
  const noPointer = { ...sourceOf(state), pointer: undefined } as unknown as ContentCatalogSource;
  assert.deepEqual(await ask(new PublishedObjectLinkService(noPointer, true), 'place', 'p'), {
    status: 'unavailable',
  });
  assert.deepEqual(
    await new PublishedObjectLinkService(sourceOf(state)).candidates({
      typeId: 'place',
      marketId: 'LV',
      text: '',
      limit: 5,
    }),
    { status: 'unavailable' },
  );
});

void test('candidates are bounded pages of currently eligible listings of one type', async () => {
  const state = world();
  publish(state, 'a-place', 'place', { body: { title: 'Quiet garden' } });
  publish(state, 'b-rental', 'rental', { body: { title: 'Quiet kayak' } });
  publish(state, 'c-place', 'place', { visibility: 'withdrawn', body: { title: 'Quiet pond' } });
  publish(state, 'd-place', 'place', { body: { title: 'Busy square' } });
  const service = new PublishedObjectLinkService(sourceOf(state), true);
  const page = await service.candidates({
    typeId: 'place',
    marketId: 'LV',
    text: 'quiet',
    limit: 50,
  });
  assert.equal(page.status, 'available');
  if (page.status === 'available') {
    assert.deepEqual(
      page.items.map((item) => item.contentId),
      ['a-place'],
    );
    assert.equal(page.nextCursor, null);
  }
  const rentals = await service.candidates({
    typeId: 'rental',
    marketId: 'LV',
    text: '',
    limit: 2,
  });
  assert.equal(rentals.status, 'available');
  if (rentals.status === 'available') {
    assert.deepEqual(
      rentals.items.map((item) => item.contentId),
      ['b-rental'],
    );
    assert.equal(rentals.nextCursor, 'b-rental');
  }
  for (const bad of [
    { limit: 0, text: '' },
    { limit: 51, text: '' },
    { limit: 1.5, text: '' },
    { limit: 5, text: 'x'.repeat(101) },
  ])
    assert.deepEqual(await service.candidates({ typeId: 'place', marketId: 'LV', ...bad }), {
      status: 'unavailable',
    });
  state.offline = true;
  assert.deepEqual(
    await service.candidates({ typeId: 'place', marketId: 'LV', text: '', limit: 5 }),
    { status: 'unavailable' },
  );
});

void test('the D3.9 Place relation keeps its answers over the shared evaluator', async () => {
  const state = world();
  publish(state, 'visible', 'place', { body: { title: 'Quiet Place' } });
  publish(state, 'hidden', 'place', { visibility: 'restricted' });
  const links = new PlaceLinkService(sourceOf(state), true);
  assert.deepEqual(await links.check({ placeId: 'visible', marketId: 'LV' }), {
    status: 'eligible',
    place: {
      contentId: 'visible',
      publishedRevisionId: 'visible-r1',
      pointerRevision: 2,
      marketId: 'LV',
      title: 'Quiet Place',
    },
  });
  assert.deepEqual(await links.check({ placeId: 'hidden', marketId: 'LV' }), {
    status: 'forbidden',
  });
  const page = await links.candidates({ marketId: 'LV', text: '', limit: 10 });
  assert.equal(page.status, 'available');
  if (page.status === 'available')
    assert.deepEqual(
      page.items.map((item) => Object.keys(item).sort()),
      [['contentId', 'marketId', 'pointerRevision', 'publishedRevisionId', 'title']],
    );
});
