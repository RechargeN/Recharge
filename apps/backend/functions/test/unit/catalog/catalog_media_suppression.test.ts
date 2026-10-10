// D2 §6 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): media that Content suppresses
// never reaches a Catalog item, and a fact without the list keeps its shape.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { factHash, parseFact } from '../../../src/modules/catalog/application/catalog_projector.js';
import {
  projectFact,
  type ContentFact,
  type SourceRevision,
} from '../../../src/modules/catalog/domain/catalog_item.js';
import { ContentFeedCatalogSource } from '../../../src/modules/catalog/infrastructure/content_catalog_source.js';
import type { ContentPublicationFeed } from '../../../src/modules/content/infrastructure/content_publication_feed.js';

const refs = { marketConfigRevisionId: 'mc-1', taxonomyRevisionId: 'tx-1' };

function fact(overrides: Partial<ContentFact> = {}): ContentFact {
  return {
    schemaVersion: 1,
    effectId: 'rev-1:ContentPublished',
    kind: 'ContentPublished',
    contentId: 'content-1',
    publishedRevisionId: 'rev-1',
    pointerRevision: 1,
    visibility: 'visible',
    typeId: 'event',
    publisherRef: { type: 'page', id: 'page-1' },
    marketId: 'LV',
    referenceRevisions: refs,
    occurredAtUtc: '2035-01-01T00:00:00.000Z',
    ...overrides,
  };
}

const revision: SourceRevision = {
  contentId: 'content-1',
  publishedRevisionId: 'rev-1',
  typeId: 'event',
  marketId: 'LV',
  referenceRevisions: refs,
  publishedAtUtc: '2026-09-01T10:00:00.000Z',
  body: {
    title: 'Ceramics evening',
    shortDescription: 'Shape your own bowl on the wheel',
    fullDescription: 'An evening of guided pottery.',
    categoryId: 'workshops_masterclasses',
    subcategoryId: 'pottery',
    format: 'offline',
    location: { city: 'Riga', latitude: 56.95, longitude: 24.1, pinConfirmed: true },
    schedule: { timezoneId: 'Europe/Riga', scheduleMode: 'oneTime' },
    eventSlots: [
      {
        id: 's1',
        localDate: '2035-10-10',
        startAtUtc: '2035-10-10T15:00:00.000Z',
        endAtUtc: '2035-10-10T17:00:00.000Z',
      },
    ],
    media: { coverImage: { mediaId: 'asset-1' }, gallery: [] },
    visibility: 'public',
  },
};

function cover(overrides: Partial<ContentFact>): string | null {
  const outcome = projectFact({
    fact: fact(overrides),
    revision,
    typeVisibilityPolicy: 'public_catalog',
  });
  assert.equal(outcome.state, 'listed');
  return outcome.state === 'listed' ? outcome.item.coverMediaId : null;
}

void test('a suppressed cover is never projected; the item stays listed', () => {
  assert.equal(cover({}), 'asset-1');
  assert.equal(cover({ suppressedMediaIds: ['asset-1'] }), null);
  assert.equal(cover({ suppressedMediaIds: ['asset-2'] }), 'asset-1');
  // A later fact without suppression (the publisher confirmed again) shows it.
  assert.equal(cover({ pointerRevision: 3, suppressedMediaIds: [] }), 'asset-1');
});

void test('the fact parser accepts only a bounded list of plain ids', () => {
  assert.ok(parseFact(fact({ suppressedMediaIds: ['asset-1'] })));
  for (const bad of [
    'asset-1',
    [''],
    [1],
    Array.from({ length: 101 }, (_, index) => `asset-${String(index)}`),
  ])
    assert.equal(parseFact({ ...fact(), suppressedMediaIds: bad }), null, JSON.stringify(bad));
});

void test('the Content fact source carries the suppressed media into every Catalog fact', async () => {
  const effect = (extra: Record<string, unknown>) => ({ ...fact(), ...extra });
  const feed = {
    effectsAfter: () =>
      Promise.resolve([effect({ suppressedMediaIds: ['asset-1'] }), effect({ effectId: 'e-2' })]),
    effectsForContent: () => Promise.resolve([effect({ suppressedMediaIds: ['asset-1'] })]),
  } as unknown as ContentPublicationFeed;
  const source = new ContentFeedCatalogSource(feed);
  const [suppressed, plain] = await source.effectsAfter(null, 10);
  assert.deepEqual(suppressed?.suppressedMediaIds, ['asset-1']);
  assert.equal(plain !== undefined && 'suppressedMediaIds' in plain, false);
  const [replayed] = await source.effectsForContent('content-1', null, 10);
  assert.deepEqual(replayed?.suppressedMediaIds, ['asset-1'], 'reconcile and rebuild replay it');
});

void test('facts without the list keep the hash they had before D2', () => {
  const before = fact();
  // The canonical form drops undefined fields: an absent list hashes like no list.
  assert.equal(
    factHash(before),
    factHash({ ...before, suppressedMediaIds: undefined } as unknown as ContentFact),
  );
  assert.notEqual(factHash(before), factHash(fact({ suppressedMediaIds: ['asset-1'] })));
});
