// D2 §5 and §6 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): what the pointer
// confirms and suppresses, how facts carry it, and that Booking sees no fact
// for a change of media only.
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  planBookingHandoff,
  type HandoffEffect,
} from '../../../src/modules/content/domain/event_internal_registration.js';
import {
  activateRevision,
  applyModerationHold,
  contentEffect,
  mediaNeedsConfirmation,
  mediaSuppressionsFor,
  suppressedMediaIds,
  suppressMedia,
  withdrawByOwner,
  type AttachedMediaState,
  type PublicationPointer,
} from '../../../src/modules/content/domain/publication_pointer.js';
import type { PublishedRevision } from '../../../src/modules/content/domain/published_revision.js';
import { parseEntityId, type EntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';

const id = (suffix: string): EntityId => parseEntityId(`01HZZZZZZZZZZZZZZZZZZZZZ${suffix}`);
const t0 = parseUtcInstant('2026-10-09T10:00:00.000Z');
const t1 = parseUtcInstant('2026-10-09T10:01:00.000Z');
const contentId = id('C1');
const revisionId = id('R1');
const assetA = id('A1');
const assetB = id('B1');
const pin = (assetId: EntityId) => ({
  assetId,
  sourceGeneration: `g-${assetId}`,
  variantManifestRevision: `m-${assetId}`,
});
const attachments = [pin(assetA), pin(assetB)];
const deliverable = (assetId: EntityId, epoch = 0): AttachedMediaState => ({
  assetId,
  state: 'deliverable',
  revocationEpoch: epoch,
  sourceGeneration: `g-${assetId}`,
  variantManifestRevision: `m-${assetId}`,
});

function published(): PublicationPointer {
  return activateRevision(null, 0, contentId, revisionId, t0, [
    { assetId: assetA, revocationEpoch: 0 },
    { assetId: assetB, revocationEpoch: 0 },
  ]);
}

void test('publication confirms the evidence epochs and stores only non-empty media lists', () => {
  const pointer = published();
  assert.deepEqual(pointer.mediaConfirmations, [
    { assetId: assetA, revocationEpoch: 0 },
    { assetId: assetB, revocationEpoch: 0 },
  ]);
  assert.equal('mediaSuppression' in pointer, false);
  const bare = activateRevision(null, 0, contentId, revisionId, t0);
  assert.equal('mediaConfirmations' in bare, false);
});

void test('suppression is decided from Media now: deletion, restriction, epoch, generation', () => {
  const pointer = published();
  const decide = (states: readonly AttachedMediaState[]) =>
    mediaSuppressionsFor(pointer, attachments, states).map((item) => [item.assetId, item.reason]);
  assert.deepEqual(decide([deliverable(assetA), deliverable(assetB)]), []);
  // A deletion hold alone: delivery is already closed, nothing is suppressed.
  assert.deepEqual(decide([{ ...deliverable(assetA), state: 'held' }, deliverable(assetB)]), []);
  assert.deepEqual(
    decide([
      { ...deliverable(assetA), state: 'restricted', revocationEpoch: 1 },
      deliverable(assetB),
    ]),
    [[assetA, 'revoked']],
  );
  // Restricted and lifted again: Media is deliverable, but the epoch moved.
  assert.deepEqual(decide([deliverable(assetA, 1), deliverable(assetB)]), [[assetA, 'revoked']]);
  assert.deepEqual(decide([{ ...deliverable(assetA), state: 'deleted', revocationEpoch: 1 }]), [
    [assetA, 'deleted'],
    [assetB, 'deleted'],
  ]);
  assert.deepEqual(
    decide([{ ...deliverable(assetA), sourceGeneration: 'other' }, deliverable(assetB)]),
    [[assetA, 'revoked']],
  );
  // Without a confirmation (published before D2) nothing is trusted.
  const unconfirmed = activateRevision(null, 0, contentId, revisionId, t0);
  assert.deepEqual(
    mediaSuppressionsFor(unconfirmed, [pin(assetA)], [deliverable(assetA)]).map(
      (item) => item.reason,
    ),
    ['revoked'],
  );
});

void test('suppression only grows here; an addition already present is no new revision', () => {
  const pointer = published();
  const once = suppressMedia(
    pointer,
    [{ assetId: assetA, reason: 'revoked', observedEpoch: 1 }],
    t1,
  );
  assert.equal(once.revision, pointer.revision + 1);
  assert.deepEqual(suppressedMediaIds(once), [assetA]);
  assert.equal(once.visibility, 'visible');
  assert.equal(once.currentPublishedRevisionId, revisionId);
  assert.equal(
    suppressMedia(once, [{ assetId: assetA, reason: 'deleted', observedEpoch: 2 }], t1),
    once,
  );
  const twice = suppressMedia(once, [{ assetId: assetB, reason: 'deleted', observedEpoch: 1 }], t1);
  assert.deepEqual(suppressedMediaIds(twice), [assetA, assetB]);
  // Holds keep what the pointer confirms and suppresses.
  const withdrawn = withdrawByOwner(twice, twice.revision, 'withdraw', t1);
  assert.deepEqual(suppressedMediaIds(withdrawn), [assetA, assetB]);
  const restricted = applyModerationHold(twice, revisionId, 'restricted', 'dec-1', t1);
  assert.deepEqual(restricted.mediaConfirmations, twice.mediaConfirmations);
  assert.deepEqual(suppressedMediaIds(restricted), [assetA, assetB]);
});

void test('only an activation clears suppression and confirms the new epochs', () => {
  const suppressed = suppressMedia(
    published(),
    [{ assetId: assetA, reason: 'revoked', observedEpoch: 1 }],
    t1,
  );
  const evidence = [
    { assetId: assetA, revocationEpoch: 1 },
    { assetId: assetB, revocationEpoch: 0 },
  ];
  assert.equal(mediaNeedsConfirmation(suppressed, evidence), true);
  const again = activateRevision(
    suppressed,
    suppressed.revision,
    contentId,
    revisionId,
    t1,
    evidence,
  );
  assert.equal('mediaSuppression' in again, false);
  assert.deepEqual(again.mediaConfirmations, evidence);
  assert.equal(again.previousPublishedRevisionId, null, 'no revision is its own predecessor');
  assert.equal(mediaNeedsConfirmation(again, evidence), false);
  // Media revoked what was confirmed although nothing is suppressed yet.
  assert.equal(
    mediaNeedsConfirmation(again, [
      { assetId: assetA, revocationEpoch: 2 },
      { assetId: assetB, revocationEpoch: 0 },
    ]),
    true,
  );
});

void test('every fact carries the suppressed media; earlier facts keep their shape', () => {
  const revision = {
    contentId,
    publishedRevisionId: revisionId,
    typeId: 'event',
    publisherRef: { type: 'page', id: 'page-1' },
    marketId: 'LV',
    referenceRevisions: {},
  } as unknown as PublishedRevision;
  const plain = contentEffect(revision, published(), 'ContentPublished', 'e-1', t0);
  assert.equal('suppressedMediaIds' in plain, false);
  const suppressed = suppressMedia(
    published(),
    [{ assetId: assetB, reason: 'deleted', observedEpoch: 1 }],
    t1,
  );
  const fact = contentEffect(revision, suppressed, 'ContentMediaAvailabilityChanged', 'e-2', t1);
  assert.deepEqual(fact.suppressedMediaIds, [assetB]);
  assert.equal(fact.pointerRevision, suppressed.revision);
  assert.equal(fact.visibility, 'visible');
});

void test('T13: Booking gets no fact for a media-only change and keeps the revision order', () => {
  const body = {
    format: 'offline',
    location: { city: 'Riga', latitude: 56.95, longitude: 24.1, pinConfirmed: true },
    pricing: { mode: 'free', paymentCollectionMode: 'none' },
    participants: { capacityMode: 'known', capacity: 20 },
    registration: {
      mode: 'internal',
      confirmationMode: 'instant',
      maxPartySize: 3,
      opensMinutesBeforeStart: 10_080,
      closesMinutesBeforeStart: 60,
      cancellationClosesMinutesBeforeStart: 120,
    },
    eventSlots: [
      {
        id: 'occ-a',
        localDate: '2035-10-10',
        startAtUtc: '2035-10-10T15:00:00.000Z',
        endAtUtc: '2035-10-10T17:00:00.000Z',
      },
    ],
  };
  const effect = (pointerRevision: number, mediaOnly?: boolean): HandoffEffect => ({
    effectId: `effect-${String(pointerRevision)}`,
    contentId: 'content-1',
    pointerRevision,
    visibility: 'visible',
    marketId: 'LV',
    publisherRef: { type: 'page', id: 'page-1' },
    occurredAtUtc: '2035-09-01T00:00:00.000Z',
    ...(mediaOnly === undefined ? {} : { mediaOnly }),
  });
  const first = planBookingHandoff(null, effect(1), body);
  assert.equal(first.facts.length, 1);
  const media = planBookingHandoff(first.next, effect(2, true), body);
  assert.deepEqual(media.facts, []);
  assert.deepEqual(media.findings, []);
  assert.equal(media.next.lastPointerRevision, 2);
  assert.deepEqual(media.next.occurrences, first.next.occurrences);
  // Without the marker the same effect republishes every occurrence.
  assert.equal(planBookingHandoff(first.next, effect(2), body).facts.length, 1);
});
