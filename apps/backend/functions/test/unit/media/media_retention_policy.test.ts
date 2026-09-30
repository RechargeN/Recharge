import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaLifecycle } from '../../../src/contracts/media_v1.js';
import { mediaLifecycles } from '../../../src/contracts/media_v1.js';
import type { EntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { MediaDomainRefusal } from '../../../src/modules/media/domain/failures.js';
import {
  createReservedAsset,
  type MediaAsset,
} from '../../../src/modules/media/domain/media_asset.js';
import {
  decideOrphan,
  mediaDataClasses,
  requireRetentionPolicy,
  type MediaRetentionPolicy,
} from '../../../src/modules/media/domain/media_retention.js';
import {
  createUploadSession,
  withSessionState,
  type UploadSession,
} from '../../../src/modules/media/domain/upload_session.js';

const t0 = parseUtcInstant('2026-09-30T09:00:00.000Z');
const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const at = (seconds: number) =>
  parseUtcInstant(new Date(Date.parse(t0) + seconds * 1000).toISOString());

/** Synthetic, explicitly TEST-ONLY retention: not an accepted product policy. */
const policy: MediaRetentionPolicy = {
  revision: 'retention-test-1',
  orphanGraceSeconds: 600,
  quarantinedRetentionSeconds: 300,
  blockedRetentionSeconds: 200,
  inFlightAttemptLeaseSeconds: 120,
  deletionReceiptRetentionSeconds: 1000,
};

function assetIn(lifecycle: MediaLifecycle, extra: Partial<MediaAsset> = {}): MediaAsset {
  return {
    ...createReservedAsset({
      assetId: id(1),
      ownerSubjectId: id(2),
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'publicDerived',
      policyRevision: 'p',
      objectKeyHandle: 'objk:test',
      nowUtc: t0,
    }),
    lifecycle,
    ...extra,
  };
}

function session(): UploadSession {
  return createUploadSession({
    uploadSessionId: id(3),
    assetId: id(1),
    ownerSubjectId: id(2),
    marketId: 'LV',
    family: 'image',
    allowedMediaTypes: ['image/jpeg'],
    maxBytes: 100,
    ttlSeconds: 900,
    objectKeyHandle: 'objk:test',
    declaredMediaType: 'image/jpeg',
    declaredByteLength: 10,
    nowUtc: t0,
  });
}

const decide = (
  asset: MediaAsset,
  over: {
    referenced?: boolean | 'unknown';
    session?: UploadSession | null;
    now?: number;
    inFlight?: boolean;
  } = {},
) =>
  decideOrphan({
    asset,
    session: over.session === undefined ? null : over.session,
    attemptInFlight: over.inFlight ?? false,
    referenced: over.referenced ?? false,
    policy,
    nowUtc: at(over.now ?? 0),
  });

void test('no retention period is invented: an absent policy is unavailable', () => {
  assert.throws(
    () => requireRetentionPolicy(undefined),
    (error: unknown) => error instanceof MediaDomainRefusal && error.code === 'policy_unavailable',
  );
  assert.equal(requireRetentionPolicy(policy), policy);
});

void test('data classes are distinct so no class inherits another retention', () => {
  assert.equal(new Set(mediaDataClasses).size, mediaDataClasses.length);
  for (const required of [
    'sourceBytes',
    'derivedVariants',
    'scanFindings',
    'auditRecords',
    'deletionReceipts',
  ])
    assert.ok((mediaDataClasses as readonly string[]).includes(required), required);
  // The receipt has its own period, separate from the bytes it covers.
  assert.notEqual(policy.deletionReceiptRetentionSeconds, policy.orphanGraceSeconds);
});

void test('in-flight assets are never deleted by cleanup and waiting assets are left alone', () => {
  for (const state of ['uploaded', 'validating', 'processing'] as const)
    assert.deepEqual(decide(assetIn(state), { now: 1_000_000 }), { action: 'keep' }, state);
});

void test('deleting resumes and deleted is left alone', () => {
  assert.deepEqual(decide(assetIn('deleting')), { action: 'resume_delete' });
  assert.deepEqual(decide(assetIn('deleted')), { action: 'keep' });
});

void test('an unfinished upload is cleaned up only after its session ended', () => {
  const open = session();
  for (const state of ['reserved', 'uploading'] as const) {
    assert.deepEqual(decide(assetIn(state), { session: open, now: 899 }), { action: 'keep' });
    assert.deepEqual(decide(assetIn(state), { session: open, now: 900 }), {
      action: 'delete',
      reason: 'expired_upload',
    });
    assert.deepEqual(decide(assetIn(state), { session: null }), {
      action: 'delete',
      reason: 'expired_upload',
    });
    assert.deepEqual(decide(assetIn(state), { session: withSessionState(open, 'aborted', t0) }), {
      action: 'delete',
      reason: 'expired_upload',
    });
  }
});

void test('a referenced asset is kept and an old mark is cleared', () => {
  for (const state of ['ready', 'quarantined', 'blocked'] as const) {
    assert.deepEqual(decide(assetIn(state), { referenced: true }), { action: 'keep' }, state);
    assert.deepEqual(
      decide(assetIn(state, { orphanSinceUtc: t0 }), { referenced: true, now: 10_000 }),
      { action: 'unmark' },
      state,
    );
  }
});

void test('an unreferenced asset is marked, then deleted only after the grace of its state', () => {
  const cases: readonly [MediaLifecycle, number][] = [
    ['ready', 600],
    ['quarantined', 300],
    ['blocked', 200],
  ];
  for (const [state, grace] of cases) {
    assert.deepEqual(decide(assetIn(state)), { action: 'mark' }, state);
    const marked = assetIn(state, { orphanSinceUtc: t0 });
    assert.deepEqual(decide(marked, { now: grace - 1 }), { action: 'keep' }, state);
    assert.deepEqual(
      decide(marked, { now: grace }),
      { action: 'delete', reason: 'orphan_cleanup' },
      state,
    );
  }
});

void test('every lifecycle state has a decision', () => {
  for (const state of mediaLifecycles)
    assert.ok(decide(assetIn(state), { session: session() }).action, state);
});

void test('an attempt without a result is abandoned only after its lease, and only if one is in flight', () => {
  for (const state of ['validating', 'processing'] as const) {
    const running = assetIn(state, { updatedAtUtc: t0 });
    assert.deepEqual(decide(running, { inFlight: true, now: 119 }), { action: 'keep' }, state);
    assert.deepEqual(
      decide(running, { inFlight: true, now: 120 }),
      { action: 'abandon_attempt' },
      state,
    );
    // Nothing started yet (the owner has not finalized): never abandoned.
    assert.deepEqual(
      decide(running, { inFlight: false, now: 1_000_000 }),
      { action: 'keep' },
      state,
    );
  }
});

void test('an unreachable owning domain leaves settled assets alone but never blocks recovery', () => {
  for (const state of ['ready', 'quarantined', 'blocked'] as const)
    assert.deepEqual(
      decide(assetIn(state, { orphanSinceUtc: t0 }), { referenced: 'unknown', now: 100_000 }),
      { action: 'keep' },
      state,
    );
  assert.deepEqual(
    decide(assetIn('validating', { updatedAtUtc: t0 }), {
      referenced: 'unknown',
      inFlight: true,
      now: 500,
    }),
    { action: 'abandon_attempt' },
  );
  assert.deepEqual(decide(assetIn('reserved'), { referenced: 'unknown', session: null }), {
    action: 'delete',
    reason: 'expired_upload',
  });
});
