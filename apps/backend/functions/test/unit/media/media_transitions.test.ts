import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaLifecycle } from '../../../src/contracts/media_v1.js';
import { mediaLifecycles } from '../../../src/contracts/media_v1.js';
import type { EntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { MediaDomainRefusal } from '../../../src/modules/media/domain/failures.js';
import {
  advance,
  createReservedAsset,
  lifecycleTransitions,
  retryFromQuarantine,
  startAttempt,
  type MediaAsset,
} from '../../../src/modules/media/domain/media_asset.js';

const now = parseUtcInstant('2026-09-30T09:00:00.000Z');
const later = parseUtcInstant('2026-09-30T09:05:00.000Z');
const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;

/** BCK-14 v0.4 §34.3, written out independently of the implementation. */
const specTable: Readonly<Record<MediaLifecycle, readonly MediaLifecycle[]>> = {
  reserved: ['uploading', 'deleted', 'deleting'],
  uploading: ['uploaded', 'deleted', 'deleting'],
  uploaded: ['validating'],
  validating: ['processing', 'quarantined', 'blocked'],
  quarantined: ['validating', 'deleting'],
  processing: ['ready', 'quarantined', 'blocked'],
  ready: ['deleting'],
  blocked: ['deleting'],
  deleting: ['deleted'],
  deleted: [],
};

function assetIn(lifecycle: MediaLifecycle, extra: Partial<MediaAsset> = {}): MediaAsset {
  const base = createReservedAsset({
    assetId: id(1),
    ownerSubjectId: id(2),
    marketId: 'LV',
    family: 'image',
    visibilityClass: 'publicDerived',
    policyRevision: 'policy-test-1',
    objectKeyHandle: 'objk:test',
    nowUtc: now,
  });
  return {
    ...base,
    lifecycle,
    sourceGenerationRef: {
      providerGeneration: 'g-1',
      byteLength: 10,
      verifiedMediaType: 'image/jpeg',
      sha256: 'a'.repeat(64),
      validationProfileRevision: 'vp-test-1',
    },
    ...extra,
  };
}

function refusal(code: string) {
  return (error: unknown) => error instanceof MediaDomainRefusal && error.code === code;
}

void test('the implemented lifecycle table equals the specified one', () => {
  assert.deepEqual(lifecycleTransitions, specTable);
  assert.deepEqual([...mediaLifecycles].sort(), Object.keys(specTable).sort());
});

void test('every single hop is allowed exactly when the table lists it', () => {
  for (const from of mediaLifecycles)
    for (const to of mediaLifecycles) {
      const allowed = specTable[from].includes(to);
      const attempt = () => advance(assetIn(from), [to], later);
      if (allowed) assert.equal(attempt().lifecycle, to, `${from} -> ${to}`);
      else assert.throws(attempt, refusal('invalid_state'), `${from} -> ${to}`);
    }
});

void test('a path is valid only if every hop is listed and bumps the revision once', () => {
  const start = assetIn('processing');
  const done = advance(start, ['ready'], later);
  assert.equal(done.revision, start.revision + 1);
  assert.equal(done.updatedAtUtc, later);
  assert.throws(() => advance(assetIn('validating'), ['ready'], later), refusal('invalid_state'));
  assert.throws(() => advance(assetIn('reserved'), ['uploaded'], later), refusal('invalid_state'));
  assert.throws(() => advance(assetIn('reserved'), [], later), refusal('invalid_state'));
  const multi = advance(assetIn('reserved'), ['uploading', 'uploaded', 'validating'], later);
  assert.equal(multi.lifecycle, 'validating');
  assert.equal(multi.revision, 2);
});

void test('quarantine has no exit except an explicit retry or deletion', () => {
  const quarantined = assetIn('quarantined');
  for (const target of mediaLifecycles.filter((item) => !['validating', 'deleting'].includes(item)))
    assert.throws(() => advance(quarantined, [target], later), refusal('invalid_state'), target);
  // `validating` is reachable by the table but only retryFromQuarantine attaches its rules.
  const retried = retryFromQuarantine(quarantined, 'g-1', 3, later);
  assert.equal(retried.lifecycle, 'validating');
  assert.equal(retried.attemptCount, quarantined.attemptCount + 1);
});

void test('retry needs the same generation, an enabled asset and an attempt budget', () => {
  const quarantined = assetIn('quarantined', { attemptCount: 1 });
  assert.throws(
    () => retryFromQuarantine(quarantined, 'g-other', 3, later),
    refusal('generation_mismatch'),
  );
  assert.throws(
    () => retryFromQuarantine(assetIn('quarantined', { attemptCount: 3 }), 'g-1', 3, later),
    refusal('retry_not_allowed'),
  );
  assert.throws(
    () => retryFromQuarantine(assetIn('quarantined', { deliveryDisabled: true }), 'g-1', 3, later),
    refusal('retry_not_allowed'),
  );
  for (const state of mediaLifecycles.filter((item) => item !== 'quarantined'))
    assert.throws(
      () => retryFromQuarantine(assetIn(state), 'g-1', 3, later),
      refusal('retry_not_allowed'),
      state,
    );
});

void test('a disabled asset never moves back towards ready but can still be deleted', () => {
  for (const from of ['validating', 'processing', 'quarantined'] as const)
    for (const to of ['validating', 'processing', 'ready'] as const)
      if (specTable[from].includes(to))
        assert.throws(
          () => advance(assetIn(from, { deliveryDisabled: true }), [to], later),
          refusal('invalid_state'),
          `${from} -> ${to}`,
        );
  assert.equal(
    advance(assetIn('ready', { deliveryDisabled: true }), ['deleting'], later).lifecycle,
    'deleting',
  );
  assert.throws(
    () => startAttempt(assetIn('validating', { deliveryDisabled: true }), later),
    refusal('invalid_state'),
  );
});

void test('deleted is terminal and blocked leaves only through deletion', () => {
  for (const to of mediaLifecycles)
    assert.throws(() => advance(assetIn('deleted'), [to], later), refusal('invalid_state'));
  for (const to of mediaLifecycles.filter((item) => item !== 'deleting'))
    assert.throws(() => advance(assetIn('blocked'), [to], later), refusal('invalid_state'));
});
