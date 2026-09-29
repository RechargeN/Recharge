/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call --
   Mutation table: each case edits a deeply nested clone of a valid JSON body, and
   the rules under test accept arbitrary untyped input by design. */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import {
  collectionMediaIds,
  collectionRuleConfig,
  validateCollectionBody,
} from '../../../src/modules/content/domain/type_rules/collection_rules.js';
import type {
  CollectionObjectType,
  ContentValidationContext,
  PublishedObjectLookup,
  ReferenceLookups,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
const obj = (suffix: string) => `018FQ2Z8Q9N4M7K2T6V3W1X5${suffix}`;

const lookups: ReferenceLookups = {
  supportsLocale: () => true,
  subcategoryApplies: (typeId, categoryId, subcategoryId) =>
    typeId === 'collection' &&
    categoryId === 'travel_tours' &&
    subcategoryId === 'hidden_gems_tour',
  requiredCriteria: () => [],
  pointInServiceArea: () => true,
};

function published(
  unavailable: readonly string[] = [],
  unresolvable: readonly string[] = [],
): PublishedObjectLookup {
  return {
    statusOf: (type: CollectionObjectType, id: string) =>
      unresolvable.includes(`${type}:${id}`)
        ? undefined
        : unavailable.includes(`${type}:${id}`)
          ? 'unavailable'
          : 'ready',
  };
}

function context(overrides: Partial<ContentValidationContext> = {}): ContentValidationContext {
  return {
    typeId: 'collection',
    marketId: 'LV',
    publisherRef: { type: 'user', id: userId as never },
    createdByUserId: userId,
    actorUserId: userId,
    nowUtc: '2026-09-29T10:00:00.000Z',
    draftRevision: 4,
    publishedObjects: published(),
    market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
    lookups,
    ...overrides,
  };
}

const item = (idSuffix: string, type: string, objectSuffix: string, order: number, extra = {}) => ({
  id: obj(idSuffix),
  ref: { objectId: obj(objectSuffix), objectType: type },
  snapshot: { title: `Item ${idSuffix}` },
  sourceStatus: 'ready',
  order,
  curatorNote: 'Worth the detour',
  highlight: false,
  ...extra,
});

function validBody(): Record<string, unknown> {
  return {
    title: 'Hidden gems of Old Riga',
    shortDescription: 'Quiet corners locals love',
    categoryId: 'travel_tours',
    subcategoryId: 'hidden_gems_tour',
    media: { coverImage: { mediaId: 'media-cover' }, gallery: [] },
    areaLabel: 'Old Riga',
    visibility: 'public',
    sections: [],
    items: [
      item('A1', 'place', 'B1', 0),
      item('A2', 'route', 'B2', 1),
      item('A3', 'rental', 'B3', 2),
    ],
    compositionReview: {
      draftRevision: 4,
      reviewedAtUtc: '2026-09-29T09:59:00.000Z',
      acknowledgedUnavailableStableKeys: [],
    },
  };
}

function withChange(change: (body: Record<string, any>) => void): Record<string, unknown> {
  const body = structuredClone(validBody());
  change(body);
  return body;
}

const check = (body: Record<string, unknown>, ctx = context()) => validateCollectionBody(body, ctx);

void test('Collection is available with its rule and media extractor', () => {
  const entry = resolveContentType('collection');
  assert.ok(entry);
  assert.equal(isContentTypeAvailable(entry), true);
  assert.equal(entry.validate, validateCollectionBody);
  assert.equal(entry.mediaIds, collectionMediaIds);
  assert.equal(entry.sourceResolver, 'published_object_membership');
  assert.equal(collectionRuleConfig.minPublishableItemCount, 3);
});

void test('a complete Collection is valid, including sections, anchor and budget', () => {
  assert.deepEqual(check(validBody()), []);
  const rich = withChange((b) => {
    b.fullDescription = 'A hand-picked walk through the quieter side of the old town.';
    b.areaId = 'riga-old-town';
    b.anchor = { latitude: 56.9496, longitude: 24.1052 };
    b.budgetTier = 'low';
    b.visibility = 'unlisted';
    b.media.gallery = [{ mediaId: 'g1' }];
    b.sections = [
      { id: 'top', title: 'Top sights', order: 0 },
      { id: 'gems', title: 'Hidden gems', order: 1 },
    ];
    b.items = [
      item('A1', 'place', 'B1', 0, { sectionId: 'top', highlight: true }),
      item('A2', 'route', 'B2', 1, { sectionId: 'top' }),
      item('A3', 'rental', 'B3', 0, { sectionId: 'gems' }),
      item('A4', 'bookableSession', 'B4', 0),
      item('A5', 'classWorkshop', 'B5', 1, { curatorNote: '' }),
    ];
  });
  assert.deepEqual(check(rich), []);
  assert.deepEqual(collectionMediaIds(rich), ['media-cover', 'g1']);
  assert.deepEqual(collectionMediaIds({}), []);
});

const crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
function ulidOf(prefix: string, n: number): string {
  const tail = `${crockford[Math.floor(n / 32) % 32]}${crockford[n % 32]}`;
  return `${prefix}${tail}`.padEnd(26, '0').slice(0, 26);
}

void test('warnings do not fail: empty notes, more than 30 items and no highlight', () => {
  const body = withChange((b) => {
    b.items = Array.from({ length: 35 }, (_, index) => ({
      id: ulidOf('018FQ2Z8Q9N4M7K2T6V3W', index),
      ref: { objectId: ulidOf('018FQ2Z8Q9N4M7K2T6V3X', index), objectType: 'place' },
      snapshot: { title: `Item ${index}` },
      order: index,
      curatorNote: '',
    }));
  });
  assert.deepEqual(check(body), []);
});

const invalidCases: ReadonlyArray<readonly [string, (body: Record<string, any>) => void, string]> =
  [
    [
      'unknown field',
      (b) => {
        b.surprise = 1;
      },
      'collection.unknown_field:surprise',
    ],
    [
      'empty title',
      (b) => {
        b.title = ' ';
      },
      'collection.title_required',
    ],
    [
      'empty pitch',
      (b) => {
        b.shortDescription = '';
      },
      'collection.short_description_required',
    ],
    [
      'empty area',
      (b) => {
        b.areaLabel = ' ';
      },
      'collection.area_required',
    ],
    [
      'bad visibility',
      (b) => {
        b.visibility = 'private';
      },
      'collection.visibility',
    ],
    [
      'bad budget tier',
      (b) => {
        b.budgetTier = 'luxury';
      },
      'collection.budget_tier',
    ],
    [
      'anchor out of range',
      (b) => {
        b.anchor = { latitude: 120, longitude: 0 };
      },
      'collection.anchor_invalid',
    ],
    [
      'category missing',
      (b) => {
        delete b.categoryId;
      },
      'collection.category_required',
    ],
    [
      'subcategory not applicable',
      (b) => {
        b.subcategoryId = 'museum';
      },
      'collection.subcategory_not_applicable',
    ],
    [
      'cover missing',
      (b) => {
        delete b.media.coverImage;
      },
      'collection.cover_image_required',
    ],
    [
      'duplicate media',
      (b) => {
        b.media.gallery = [{ mediaId: 'media-cover' }];
      },
      'collection.media_duplicate',
    ],
    [
      'two items are not enough',
      (b) => {
        b.items = b.items.slice(0, 2);
      },
      'collection.min_items',
    ],
    [
      'items missing',
      (b) => {
        delete b.items;
      },
      'collection.items_required',
    ],
    [
      'duplicate object reference',
      (b) => {
        b.items[1].ref = structuredClone(b.items[0].ref);
      },
      'collection.duplicate_item',
    ],
    [
      'a Collection cannot be referenced',
      (b) => {
        b.items[0].ref.objectType = 'collection';
      },
      'collection.item_ref_invalid',
    ],
    [
      'a Scenario cannot be referenced',
      (b) => {
        b.items[0].ref.objectType = 'scenario';
      },
      'collection.item_ref_invalid',
    ],
    [
      'an Event cannot be referenced',
      (b) => {
        b.items[0].ref.objectType = 'event';
      },
      'collection.item_ref_invalid',
    ],
    [
      'an Activity cannot be referenced',
      (b) => {
        b.items[0].ref.objectType = 'activity';
      },
      'collection.item_ref_invalid',
    ],
    [
      'Find People cannot be referenced',
      (b) => {
        b.items[0].ref.objectType = 'findPeople';
      },
      'collection.item_ref_invalid',
    ],
    [
      'object id is a local key',
      (b) => {
        b.items[0].ref.objectId = 'loc_place';
      },
      'collection.item_ref_invalid',
    ],
    [
      'item id is a local key',
      (b) => {
        b.items[0].id = 'loc_item';
      },
      'collection.item_id_invalid',
    ],
    [
      'duplicate item id',
      (b) => {
        b.items[1].id = b.items[0].id;
      },
      'collection.item_id_duplicate',
    ],
    [
      'item id equals the object id',
      (b) => {
        b.items[0].ref.objectId = b.items[0].id;
      },
      'collection.item_id_is_object_id',
    ],
    [
      'orphan section',
      (b) => {
        b.items[0].sectionId = 'missing';
      },
      'collection.orphan_section',
    ],
    [
      'sparse item order',
      (b) => {
        b.items[2].order = 5;
      },
      'collection.item_order_not_dense',
    ],
    [
      'sparse section order',
      (b) => {
        b.sections = [{ id: 's1', title: 'One', order: 3 }];
      },
      'collection.section_order_not_dense',
    ],
    [
      'duplicate section',
      (b) => {
        b.sections = [
          { id: 's', title: 'A', order: 0 },
          { id: 's', title: 'B', order: 1 },
        ];
      },
      'collection.section_duplicate',
    ],
    [
      'section without a title',
      (b) => {
        b.sections = [{ id: 's', title: '', order: 0 }];
      },
      'collection.section_invalid',
    ],
    [
      'curator note over 300 graphemes',
      (b) => {
        b.items[0].curatorNote = 'x'.repeat(301);
      },
      'collection.curator_note_length',
    ],
    [
      'curator note of emoji counts graphemes not code units',
      (b) => {
        b.items[0].curatorNote = '👨‍👩‍👧'.repeat(301);
      },
      'collection.curator_note_length',
    ],
    [
      'unknown source status',
      (b) => {
        b.items[0].sourceStatus = 'gone';
      },
      'collection.source_status',
    ],
    [
      'snapshot with geo',
      (b) => {
        b.items[0].snapshot.latitude = 56.9;
      },
      'collection.snapshot_geo_forbidden',
    ],
    [
      'snapshot with a location',
      (b) => {
        b.items[0].snapshot.location = { lat: 1, lng: 2 };
      },
      'collection.snapshot_geo_forbidden',
    ],
    [
      'snapshot price is floating point',
      (b) => {
        b.items[0].snapshot.priceFromMinorUnits = 9.5;
      },
      'collection.snapshot_price',
    ],
    [
      'snapshot without a title',
      (b) => {
        b.items[0].snapshot.title = '';
      },
      'collection.snapshot_title',
    ],
    [
      'highlight not boolean',
      (b) => {
        b.items[0].highlight = 'yes';
      },
      'collection.highlight_invalid',
    ],
    [
      'unreplaced local media id',
      (b) => {
        b.media.coverImage.mediaId = 'loc_cover';
      },
      'collection.local_id_unreplaced',
    ],
    [
      'review missing',
      (b) => {
        delete b.compositionReview;
      },
      'collection.composition_review_required',
    ],
    [
      'review for another revision',
      (b) => {
        b.compositionReview.draftRevision = 3;
      },
      'collection.composition_review_stale',
    ],
    [
      'review timestamp invalid',
      (b) => {
        b.compositionReview.reviewedAtUtc = 'later';
      },
      'collection.composition_review_stale',
    ],
    [
      'review acknowledges an object that is not in the Collection',
      (b) => {
        b.compositionReview.acknowledgedUnavailableStableKeys = [`place:${obj('ZZ')}`];
      },
      'collection.composition_review_mismatch',
    ],
  ];

for (const [name, change, code] of invalidCases)
  void test(`Collection rejects: ${name}`, () => {
    const issues = check(withChange(change));
    assert.ok(issues.includes(code), `${code} not in ${JSON.stringify(issues)}`);
  });

void test('an unavailable object needs an exact acknowledgement in the current review', () => {
  const unavailableKey = `route:${obj('B2')}`;
  const live = context({ publishedObjects: published([unavailableKey]) });
  // Unacknowledged: blocks.
  assert.ok(check(validBody(), live).includes('collection.composition_review_mismatch'));
  // Exact acknowledgement: allowed to publish without a public card for that item.
  const acknowledged = withChange((b) => {
    b.compositionReview.acknowledgedUnavailableStableKeys = [unavailableKey];
  });
  assert.deepEqual(check(acknowledged, live), []);
  // Over-acknowledging an available object is also a mismatch.
  const over = withChange((b) => {
    b.compositionReview.acknowledgedUnavailableStableKeys = [unavailableKey, `place:${obj('B1')}`];
  });
  assert.ok(check(over, live).includes('collection.composition_review_mismatch'));
});

void test('any edit after the review bumps the revision and invalidates it', () => {
  assert.deepEqual(check(validBody(), context({ draftRevision: 4 })), []);
  assert.ok(
    check(validBody(), context({ draftRevision: 5 })).includes(
      'collection.composition_review_stale',
    ),
  );
});

void test('a client-supplied source status never decides availability', () => {
  const lying = withChange((b) => {
    b.items[0].sourceStatus = 'ready';
  });
  const live = context({ publishedObjects: published([`place:${obj('B1')}`]) });
  assert.ok(check(lying, live).includes('collection.composition_review_mismatch'));
});

void test('unresolvable published objects fail closed', () => {
  const none = context({ publishedObjects: published([], [`place:${obj('B1')}`]) });
  assert.ok(check(validBody(), none).includes('collection.published_objects_unavailable'));
  const withoutLookup = { ...context() };
  Reflect.deleteProperty(withoutLookup, 'publishedObjects');
  assert.ok(check(validBody(), withoutLookup).includes('collection.published_objects_unavailable'));
});

void test('an unanswered taxonomy authority fails closed', () => {
  const unavailable = context({ lookups: { ...lookups, subcategoryApplies: () => undefined } });
  assert.ok(check(validBody(), unavailable).includes('collection.taxonomy_unavailable'));
});
