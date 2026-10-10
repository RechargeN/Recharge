// D2 §3 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): the revocation epoch is the
// durable marker that survives a lifted restriction, and only the restore of the
// active decision lifts it.
import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaLifecycle } from '../../../src/contracts/media_v1.js';
import type { EntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { MediaDomainRefusal } from '../../../src/modules/media/domain/failures.js';
import {
  abortUpload,
  beginDeletion,
  createReservedAsset,
  placeDeletionHold,
  releaseDeletionHold,
  revocationEpochOf,
  toAssetView,
  withRestriction,
  type MediaAsset,
} from '../../../src/modules/media/domain/media_asset.js';

const now = parseUtcInstant('2026-10-09T09:00:00.000Z');
const later = parseUtcInstant('2026-10-09T09:05:00.000Z');
const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;

function assetIn(lifecycle: MediaLifecycle): MediaAsset {
  return {
    ...createReservedAsset({
      assetId: id(1),
      ownerSubjectId: id(2),
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'publicDerived',
      policyRevision: 'policy-test-1',
      objectKeyHandle: 'objk:test',
      nowUtc: now,
    }),
    lifecycle,
  };
}

const refusal = (code: string) => (error: unknown) =>
  error instanceof MediaDomainRefusal && error.code === code;

void test('every applied restriction decision raises the epoch; lifting never lowers it', () => {
  const ready = assetIn('ready');
  assert.equal(revocationEpochOf(ready), 0);
  const restricted = withRestriction(ready, { restricted: true, decisionRef: 'd-1' }, later);
  assert.equal(restricted.deliveryDisabled, true);
  assert.equal(restricted.restrictionDecisionRef, 'd-1');
  assert.equal(revocationEpochOf(restricted), 1);
  // The same decision again changes nothing (not even the revision).
  assert.equal(
    withRestriction(restricted, { restricted: true, decisionRef: 'd-1' }, later),
    restricted,
  );
  // A newer decision replaces the older one and is a new revocation.
  const replaced = withRestriction(restricted, { restricted: true, decisionRef: 'd-2' }, later);
  assert.equal(replaced.restrictionDecisionRef, 'd-2');
  assert.equal(revocationEpochOf(replaced), 2);
  const lifted = withRestriction(
    replaced,
    { restricted: false, restoresDecisionRef: 'd-2' },
    later,
  );
  assert.equal(lifted.deliveryDisabled, false);
  assert.equal(lifted.restricted, undefined);
  assert.equal(lifted.restrictionDecisionRef, undefined);
  // The marker survives the lift: what was confirmed at epoch 0 never matches again.
  assert.equal(revocationEpochOf(lifted), 2);
});

void test('only the restore of exactly the active decision lifts a restriction', () => {
  const restricted = withRestriction(
    withRestriction(assetIn('ready'), { restricted: true, decisionRef: 'd-1' }, later),
    { restricted: true, decisionRef: 'd-2' },
    later,
  );
  assert.throws(
    () => withRestriction(restricted, { restricted: false, restoresDecisionRef: 'd-1' }, later),
    refusal('stale_revision'),
  );
  assert.throws(
    () => withRestriction(restricted, { restricted: false, restoresDecisionRef: undefined }, later),
    refusal('stale_revision'),
  );
  // Lifting what is not restricted is no change at all.
  const ready = assetIn('ready');
  assert.equal(
    withRestriction(ready, { restricted: false, restoresDecisionRef: 'd-9' }, later),
    ready,
  );
});

void test('deletion raises the epoch; a deletion hold alone does not', () => {
  const ready = assetIn('ready');
  const held = placeDeletionHold(
    ready,
    { holdId: 'h-1', expiresAtUtc: parseUtcInstant('2026-10-09T09:10:00.000Z') },
    later,
  );
  assert.equal(held.deliveryDisabled, true);
  assert.equal(revocationEpochOf(held), 0);
  assert.equal(revocationEpochOf(releaseDeletionHold(held, 'h-1', later)), 0);
  assert.equal(revocationEpochOf(beginDeletion(held, later)), 1);
  assert.equal(revocationEpochOf(abortUpload(assetIn('uploading'), true, later)), 1);
  assert.equal(revocationEpochOf(abortUpload(assetIn('reserved'), false, later)), 1);
  // A restriction placed during a hold keeps both and raises the epoch once.
  const both = withRestriction(held, { restricted: true, decisionRef: 'd-1' }, later);
  assert.equal(both.deletionHold?.holdId, 'h-1');
  assert.equal(revocationEpochOf(both), 1);
});

void test('a deleted asset cannot be restricted or lifted', () => {
  for (const lifecycle of ['deleting', 'deleted'] as const) {
    assert.throws(
      () => withRestriction(assetIn(lifecycle), { restricted: true, decisionRef: 'd-1' }, later),
      refusal('invalid_state'),
    );
  }
});

void test('the owner view never shows the marker or the decision', () => {
  const restricted = withRestriction(
    assetIn('ready'),
    { restricted: true, decisionRef: 'd-1' },
    later,
  );
  const view = toAssetView(restricted) as Record<string, unknown>;
  assert.equal('revocationEpoch' in view, false);
  assert.equal('restrictionDecisionRef' in view, false);
  assert.equal('objectKeyHandle' in view, false);
  assert.equal(view.restricted, true);
});
