import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaVariantRefV1 } from '../../../src/contracts/media_v1.js';
import type { EntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { MediaDomainRefusal } from '../../../src/modules/media/domain/failures.js';
import {
  acceptSource,
  canonicalJson,
  createReservedAsset,
  markReady,
  sha256Hex,
  toAssetView,
  type MediaAsset,
} from '../../../src/modules/media/domain/media_asset.js';
import { verifyVariantManifest } from '../../../src/modules/media/domain/media_variant.js';
import {
  resolveFamilyPolicy,
  type MediaPolicy,
} from '../../../src/modules/media/domain/media_policy.js';
import {
  createUploadSession,
  isSessionExpired,
  toSessionView,
  withSessionState,
} from '../../../src/modules/media/domain/upload_session.js';

const now = parseUtcInstant('2026-09-30T09:00:00.000Z');
const later = parseUtcInstant('2026-09-30T09:20:00.000Z');
const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;

/** Synthetic, explicitly TEST-ONLY policy: not an accepted product policy. */
const testPolicy: MediaPolicy = {
  revision: 'policy-test-1',
  families: {
    image: {
      allowedMediaTypes: ['image/jpeg', 'image/png'],
      maxBytes: 4096,
      sessionTtlSeconds: 900,
      maxProcessingAttempts: 3,
      mandatoryVariantProfiles: ['display', 'thumb'],
      validationProfileRevision: 'vp-test-1',
    },
  },
};

function reserved(): MediaAsset {
  return createReservedAsset({
    assetId: id(1),
    ownerSubjectId: id(2),
    publisherRef: { type: 'page', id: id(3) },
    entityBinding: { domain: 'content', entityId: id(4), purpose: 'contentMedia' },
    marketId: 'LV',
    family: 'image',
    visibilityClass: 'publicDerived',
    policyRevision: 'policy-test-1',
    objectKeyHandle: 'objk:secret-handle',
    nowUtc: now,
  });
}

const source = {
  providerGeneration: 'g-1',
  byteLength: 2048,
  verifiedMediaType: 'image/jpeg',
  sha256: 'a'.repeat(64),
  validationProfileRevision: 'vp-test-1',
};

function variant(profile: string, n: number, over: Partial<MediaVariantRefV1> = {}) {
  return {
    variantId: id(100 + n),
    profile,
    format: 'image/webp',
    providerGeneration: `vg-${n}`,
    sha256: n.toString(16).padStart(64, '0'),
    byteLength: 100 + n,
    transformProfileRevision: 'tp-test-1',
    sourceProviderGeneration: 'g-1',
    ...over,
  };
}

function validating(): MediaAsset {
  return acceptSource(reserved(), source, now);
}

void test('a reserved asset is frozen, owned and carries the backend-selected key', () => {
  const asset = reserved();
  assert.equal(asset.lifecycle, 'reserved');
  assert.equal(asset.revision, 1);
  assert.equal(asset.deliveryDisabled, false);
  assert.equal(asset.attemptCount, 0);
  assert.equal(Object.isFrozen(asset), true);
  assert.equal(asset.objectKeyHandle, 'objk:secret-handle');
});

void test('the wire view never carries the object key or bucket detail', () => {
  const view = toAssetView(reserved());
  assert.equal('objectKeyHandle' in view, false);
  assert.equal(JSON.stringify(view).includes('secret-handle'), false);
  const session = createUploadSession({
    uploadSessionId: id(5),
    assetId: id(1),
    ownerSubjectId: id(2),
    marketId: 'LV',
    family: 'image',
    allowedMediaTypes: ['image/jpeg'],
    maxBytes: 4096,
    ttlSeconds: 900,
    objectKeyHandle: 'objk:secret-handle',
    declaredMediaType: 'image/jpeg',
    declaredByteLength: 2048,
    nowUtc: now,
  });
  const wire = toSessionView(session);
  assert.equal(JSON.stringify(wire).includes('secret-handle'), false);
  assert.equal('declaredMediaType' in wire, false);
});

void test('accepting a source pins its generation and moves reserved to validating', () => {
  const asset = validating();
  assert.equal(asset.lifecycle, 'validating');
  assert.equal(asset.sourceGenerationRef?.providerGeneration, 'g-1');
  assert.equal(asset.revision, 2);
});

void test('the variant manifest needs every mandatory profile on the pinned source generation', () => {
  const asset = validating();
  const good = [variant('thumb', 2), variant('display', 1)];
  const manifest = verifyVariantManifest(asset, good, ['display', 'thumb']);
  assert.equal(manifest.ok, true);
  const reversed = verifyVariantManifest(asset, [...good].reverse(), ['display', 'thumb']);
  assert.equal(reversed.ok && manifest.ok && reversed.revision === manifest.revision, true);
  assert.equal(manifest.ok && manifest.variants[0]?.profile, 'display');
  const bad: readonly (readonly MediaVariantRefV1[])[] = [
    [],
    [variant('display', 1)],
    [variant('display', 1), variant('display', 2), variant('thumb', 3)],
    [variant('display', 1, { sourceProviderGeneration: 'g-other' }), variant('thumb', 2)],
    [variant('display', 1, { providerGeneration: 'g-1' }), variant('thumb', 2)],
    [variant('display', 1, { sha256: 'xyz' }), variant('thumb', 2)],
    [variant('display', 1, { byteLength: 0 }), variant('thumb', 2)],
  ];
  for (const [index, variants] of bad.entries())
    assert.equal(
      verifyVariantManifest(asset, variants, ['display', 'thumb']).ok,
      false,
      `${index}`,
    );
  assert.equal(verifyVariantManifest(reserved(), good, ['display', 'thumb']).ok, false);
});

void test('the manifest revision changes with any variant byte or generation', () => {
  const asset = validating();
  const first = verifyVariantManifest(asset, [variant('display', 1)], ['display']);
  const second = verifyVariantManifest(
    asset,
    [variant('display', 1, { sha256: 'e'.repeat(64) })],
    ['display'],
  );
  assert.ok(first.ok && second.ok);
  assert.notEqual(first.revision, second.revision);
});

void test('ready carries the verified variants and the manifest revision', () => {
  const asset = advanceToProcessing(validating());
  const manifest = verifyVariantManifest(
    asset,
    [variant('display', 1), variant('thumb', 2)],
    ['display', 'thumb'],
  );
  assert.ok(manifest.ok);
  const ready = markReady(asset, manifest, later);
  assert.equal(ready.lifecycle, 'ready');
  assert.equal(ready.variantManifestRevision, manifest.revision);
  assert.equal(ready.variantRefs.length, 2);
});

function advanceToProcessing(asset: MediaAsset): MediaAsset {
  return { ...asset, lifecycle: 'processing' };
}

void test('canonical JSON is key-order independent and hashes are stable', () => {
  assert.equal(canonicalJson({ b: 1, a: [2, { d: 1, c: undefined }] }), '{"a":[2,{"d":1}],"b":1}');
  assert.equal(canonicalJson({ a: 1, b: 2 }), canonicalJson({ b: 2, a: 1 }));
  assert.equal(sha256Hex('x'), sha256Hex('x'));
  assert.notEqual(sha256Hex('x'), sha256Hex('y'));
});

void test('policy is never invented: none is unavailable and unlisted families fail closed', () => {
  assert.throws(
    () => resolveFamilyPolicy(undefined, 'image'),
    (error: unknown) => error instanceof MediaDomainRefusal && error.code === 'policy_unavailable',
  );
  assert.throws(
    () => resolveFamilyPolicy(testPolicy, 'video'),
    (error: unknown) => error instanceof MediaDomainRefusal && error.code === 'family_unavailable',
  );
  assert.equal(resolveFamilyPolicy(testPolicy, 'image').maxBytes, 4096);
});

void test('an upload session enforces its limits, expires and completes once', () => {
  const input = {
    uploadSessionId: id(5),
    assetId: id(1),
    ownerSubjectId: id(2),
    marketId: 'LV' as const,
    family: 'image' as const,
    allowedMediaTypes: ['image/jpeg'],
    maxBytes: 4096,
    ttlSeconds: 900,
    objectKeyHandle: 'objk:x',
    declaredMediaType: 'image/jpeg',
    declaredByteLength: 2048,
    nowUtc: now,
  };
  const session = createUploadSession(input);
  assert.equal(session.expiresAtUtc, '2026-09-30T09:15:00.000Z');
  assert.equal(isSessionExpired(session, now), false);
  assert.equal(isSessionExpired(session, later), true);
  assert.throws(
    () => createUploadSession({ ...input, declaredByteLength: 4097 }),
    (error: unknown) => error instanceof MediaDomainRefusal && error.code === 'limit_exceeded',
  );
  assert.throws(
    () => createUploadSession({ ...input, declaredMediaType: 'image/gif' }),
    (error: unknown) => error instanceof MediaDomainRefusal && error.code === 'limit_exceeded',
  );
  const completed = withSessionState(session, 'completed', now);
  assert.equal(completed.completedAtUtc, now);
  assert.throws(
    () => withSessionState(completed, 'aborted', now),
    (error: unknown) => error instanceof MediaDomainRefusal && error.code === 'invalid_state',
  );
});
