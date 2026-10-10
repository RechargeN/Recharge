// D3.1 (PLACE_D3_1_PUBLICATION_AMENDMENT.md §7): the stand digest of a Place
// removes only unstable technical values — random server ids (named from the
// manifest), the fake processor's per-process variant numbers, and the order
// of lists the domain stores sorted by asset id — and keeps every difference
// that matters: gallery composition and order, bindings, revisions,
// confirmations and suppression.
import assert from 'node:assert/strict';
import test from 'node:test';

import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { standManifestCollection } from './stand_content_event.js';
import { digestStandState, type Plain, type RawStandState } from './stand_digest.js';

/** Random server ids of one run; another run has other ids. */
interface Ids {
  readonly content: string;
  readonly draft: string;
  readonly revision: string;
  readonly submission: string;
  readonly decision: string;
  readonly cover: string;
  readonly gallery: readonly [string, string];
  readonly sessions: readonly [string, string, string];
  readonly objects: readonly [string, string, string];
}

const runA: Ids = {
  content: 'c7a1f9e2-1111-4a00-8000-00000000a001',
  draft: 'd7a1f9e2-1111-4a00-8000-00000000a002',
  revision: 'e7a1f9e2-1111-4a00-8000-00000000a003',
  submission: 'f7a1f9e2-1111-4a00-8000-00000000a004',
  decision: 'a8a1f9e2-1111-4a00-8000-00000000a005',
  cover: '17a1f9e2-1111-4a00-8000-00000000a006',
  gallery: ['97a1f9e2-1111-4a00-8000-00000000a007', '27a1f9e2-1111-4a00-8000-00000000a008'],
  sessions: [
    '37a1f9e2-1111-4a00-8000-00000000a009',
    '47a1f9e2-1111-4a00-8000-00000000a00a',
    '57a1f9e2-1111-4a00-8000-00000000a00b',
  ],
  objects: ['objk-run-a-cover', 'objk-run-a-g1', 'objk-run-a-g2'],
};

// Other ids, and an asset-id order that is the reverse of run A's.
const runB: Ids = {
  content: '0b2c3d4e-2222-4b00-8000-00000000b001',
  draft: '1b2c3d4e-2222-4b00-8000-00000000b002',
  revision: '2b2c3d4e-2222-4b00-8000-00000000b003',
  submission: '3b2c3d4e-2222-4b00-8000-00000000b004',
  decision: '4b2c3d4e-2222-4b00-8000-00000000b005',
  cover: '5b2c3d4e-2222-4b00-8000-00000000b006',
  gallery: ['1c2c3d4e-2222-4b00-8000-00000000b007', '9c2c3d4e-2222-4b00-8000-00000000b008'],
  sessions: [
    '6b2c3d4e-2222-4b00-8000-00000000b009',
    '7b2c3d4e-2222-4b00-8000-00000000b00a',
    '8b2c3d4e-2222-4b00-8000-00000000b00b',
  ],
  objects: ['objk-run-b-cover', 'objk-run-b-g1', 'objk-run-b-g2'],
};

const byId = <T extends { assetId: string }>(items: T[]): T[] =>
  [...items].sort((left, right) => left.assetId.localeCompare(right.assetId));

interface Variation {
  /** First variant number of the fake processor in this run. */
  readonly variantBase?: number;
  readonly mutate?: (state: Map<string, Map<string, Plain>>, ids: Ids) => void;
}

/** One stand state with a published Place, shaped like the stored documents. */
function placeState(ids: Ids, variation: Variation = {}): RawStandState {
  const images = [ids.cover, ...ids.gallery];
  let counter = variation.variantBase ?? 1;
  const variant = () => {
    const n = counter++;
    return {
      variantId: `01${String(n).padStart(24, '0')}`,
      profile: 'display',
      format: 'image/webp',
      providerGeneration: `variant-generation-${n}`,
      sha256: n.toString(16).padStart(64, '0'),
      byteLength: 100 + n,
    };
  };
  const body = {
    title: 'Kronvalda park pond',
    media: {
      coverImage: { mediaId: ids.cover },
      gallery: ids.gallery.map((mediaId) => ({ mediaId })),
    },
  };
  const attachments = byId(
    images.map((assetId) => ({
      assetId,
      sourceGeneration: `gen-${assetId}`,
      variantManifestRevision: `m1_${'a'.repeat(64)}`,
      purpose: 'contentMedia',
    })),
  );
  const state = new Map<string, Map<string, Plain>>([
    [
      standManifestCollection,
      new Map([
        [
          'seed',
          {
            schemaVersion: 1,
            contentPlace: {
              pageId: 'page-studio',
              contentId: ids.content,
              draftId: ids.draft,
              createdByUserId: 'user-creator',
              submissionId: ids.submission,
              publishedRevisionId: ids.revision,
              coverAssetId: ids.cover,
              galleryAssetIds: [...ids.gallery],
              approveDecisionId: ids.decision,
              completedAtUtc: '2026-10-10T12:00:00.000Z',
            },
          },
        ],
      ]),
    ],
    [
      mediaCollections.assets,
      new Map(
        images.map((assetId, index) => [
          assetId,
          {
            assetId,
            lifecycle: 'ready',
            byteLength: 69,
            objectKeyHandle: ids.objects[index],
            entityBinding: { domain: 'content', entityId: ids.content },
            variantRefs: [variant()],
          },
        ]),
      ),
    ],
    [
      mediaCollections.sessions,
      new Map(
        images.map((assetId, index) => [
          ids.sessions[index] as string,
          { assetId, state: 'finalized' },
        ]),
      ),
    ],
    [
      contentCollections.drafts,
      new Map([
        [
          ids.draft,
          {
            contentId: ids.content,
            revision: 2,
            bodyJson: JSON.stringify(body),
            // The draft keeps the body's order (cover, then the gallery as ordered).
            mediaAssetIds: [ids.cover, ...ids.gallery],
          },
        ],
      ]),
    ],
    [
      contentCollections.publishedRevisions,
      new Map([
        [
          ids.revision,
          {
            contentId: ids.content,
            bodyJson: JSON.stringify(body),
            mediaAttachments: attachments,
            mediaAssetIds: attachments.map((item) => item.assetId),
          },
        ],
      ]),
    ],
    [
      contentCollections.pointers,
      new Map([
        [
          ids.content,
          {
            contentId: ids.content,
            currentPublishedRevisionId: ids.revision,
            visibility: 'visible',
            revision: 1,
            mediaConfirmations: byId(images.map((assetId) => ({ assetId, revocationEpoch: 0 }))),
          },
        ],
      ]),
    ],
  ]);
  variation.mutate?.(state, ids);
  return state;
}

const digest = (state: RawStandState) => digestStandState(state, []).digest;
const doc = (state: Map<string, Map<string, Plain>>, collection: string, id: string): Plain => {
  const found = state.get(collection)?.get(id);
  assert.ok(found, `${collection}/${id}`);
  return found;
};

const baseline = digest(placeState(runA));

void test('another run of the same Place has the same digest', () => {
  // Other random ids, a reversed asset-id order, other fake variant numbers.
  assert.equal(digest(placeState(runB, { variantBase: 7 })), baseline);
  assert.equal(digest(placeState(runA, { variantBase: 3 })), baseline);
});

type Mutation = NonNullable<Variation['mutate']>;

const changes: Readonly<Record<string, Mutation>> = {
  'a gallery photo removed from the published revision': (state, ids) => {
    const revision = doc(state, contentCollections.publishedRevisions, ids.revision);
    revision.mediaAttachments = (revision.mediaAttachments as { assetId: string }[]).filter(
      (item) => item.assetId !== ids.gallery[1],
    );
  },
  'the gallery reordered in the body': (state, ids) => {
    for (const [collection, id] of [
      [contentCollections.drafts, ids.draft],
      [contentCollections.publishedRevisions, ids.revision],
    ] as const) {
      const stored = doc(state, collection, id);
      const body = JSON.parse(stored.bodyJson as string) as {
        media: { gallery: unknown[] };
      };
      body.media.gallery.reverse();
      stored.bodyJson = JSON.stringify(body);
    }
  },
  "the draft's media order changed": (state, ids) => {
    doc(state, contentCollections.drafts, ids.draft).mediaAssetIds = [
      ids.cover,
      ids.gallery[1],
      ids.gallery[0],
    ];
  },
  'a photo bound to another content': (state, ids) => {
    doc(state, mediaCollections.assets, ids.gallery[0]).entityBinding = {
      domain: 'content',
      entityId: 'another-content',
    };
  },
  'the pointer on another revision': (state, ids) => {
    doc(state, contentCollections.pointers, ids.content).currentPublishedRevisionId =
      'another-revision';
  },
  'a changed revision body': (state, ids) => {
    doc(state, contentCollections.publishedRevisions, ids.revision).bodyJson = JSON.stringify({
      title: 'Another title',
    });
  },
  'a gallery photo suppressed': (state, ids) => {
    doc(state, contentCollections.pointers, ids.content).mediaSuppression = [
      { assetId: ids.gallery[0], reason: 'restricted', revocationEpoch: 1 },
    ];
  },
  'another confirmed epoch': (state, ids) => {
    const pointer = doc(state, contentCollections.pointers, ids.content);
    pointer.mediaConfirmations = (
      pointer.mediaConfirmations as { assetId: string; revocationEpoch: number }[]
    ).map((item) => (item.assetId === ids.gallery[0] ? { ...item, revocationEpoch: 1 } : item));
  },
  'a restricted photo': (state, ids) => {
    doc(state, mediaCollections.assets, ids.gallery[1]).lifecycle = 'restricted';
  },
  "a source image's length": (state, ids) => {
    doc(state, mediaCollections.assets, ids.cover).byteLength = 70;
  },
  'a variant profile': (state, ids) => {
    const asset = doc(state, mediaCollections.assets, ids.cover);
    asset.variantRefs = (asset.variantRefs as Plain[]).map((item) => ({
      ...item,
      profile: 'thumbnail',
    }));
  },
};

for (const [name, mutate] of Object.entries(changes)) {
  void test(`a significant change alters the digest: ${name}`, () => {
    assert.notEqual(digest(placeState(runA, { mutate })), baseline, name);
    // Also against another run's ids: the change, not the ids, is what counts.
    assert.notEqual(digest(placeState(runB, { variantBase: 7, mutate })), baseline, name);
  });
}

// D3.2 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md §7): the seeded Activity is
// named from its own manifest entry the same way, with its own labels.
void test('a seeded Activity is labelled from its manifest like the Place', () => {
  const asActivity: Mutation = (state) => {
    const seed = doc(state, standManifestCollection, 'seed');
    seed.contentActivity = seed.contentPlace;
    delete seed.contentPlace;
  };
  const activityA = digestStandState(placeState(runA, { mutate: asActivity }), []);
  const activityB = digestStandState(placeState(runB, { variantBase: 7, mutate: asActivity }), []);
  assert.equal(activityB.digest, activityA.digest);
  assert.notEqual(activityA.digest, baseline);
  const text = JSON.stringify(activityA.normalized);
  assert.match(text, /content:seed-activity/);
  assert.match(text, /asset:seed-activity-gallery-2/);
  assert.doesNotMatch(text, /seed-place/);
});
