import assert from 'node:assert/strict';
import test from 'node:test';

import type { MediaVariantRefV1 } from '../../../src/contracts/media_v1.js';
import type { EntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import {
  acceptSource,
  advance,
  createReservedAsset,
  markReady,
  type MediaAsset,
} from '../../../src/modules/media/domain/media_asset.js';
import {
  toVariantMetadata,
  variantsPreserveHistory,
  verifyVariantManifest,
} from '../../../src/modules/media/domain/media_variant.js';

const now = parseUtcInstant('2026-09-30T09:00:00.000Z');
const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;

function validating(): MediaAsset {
  return acceptSource(
    createReservedAsset({
      assetId: id(1),
      ownerSubjectId: id(2),
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'publicDerived',
      policyRevision: 'policy-test-1',
      objectKeyHandle: 'objk:test',
      nowUtc: now,
    }),
    {
      providerGeneration: 'g-1',
      byteLength: 10,
      verifiedMediaType: 'image/jpeg',
      sha256: 'a'.repeat(64),
      validationProfileRevision: 'vp-test-1',
    },
    now,
  );
}

function variant(
  profile: string,
  n: number,
  over: Partial<MediaVariantRefV1> = {},
): MediaVariantRefV1 {
  return {
    variantId: id(100 + n),
    profile,
    format: 'image/webp',
    providerGeneration: `vg-${n}`,
    sha256: n.toString(16).padStart(64, '0'),
    byteLength: 100 + n,
    transformProfileRevision: 'tp-test-1',
    sourceProviderGeneration: 'g-1',
    width: 800,
    height: 600,
    ...over,
  };
}

function readyAsset(): MediaAsset {
  const processing = advance(validating(), ['processing'], now);
  const manifest = verifyVariantManifest(
    processing,
    [variant('display', 1), variant('thumb', 2, { width: 100, height: 75 })],
    ['display', 'thumb'],
  );
  assert.ok(manifest.ok);
  return markReady(processing, manifest, now);
}

void test('variant history is immutable: a new set never reuses an earlier generation', () => {
  const first = [variant('display', 1), variant('thumb', 2)];
  assert.equal(variantsPreserveHistory([], first), true);
  assert.equal(variantsPreserveHistory(first, [variant('display', 3), variant('thumb', 4)]), true);
  assert.equal(
    variantsPreserveHistory(first, [variant('display', 3, { providerGeneration: 'vg-1' })]),
    false,
  );
  assert.equal(variantsPreserveHistory(first, first), false);
});

void test('variant metadata exposes shape only, never generations, hashes or byte counts', () => {
  const metadata = toVariantMetadata(readyAsset());
  assert.deepEqual(
    metadata.map((item) => item.profile),
    ['display', 'thumb'],
  );
  const text = JSON.stringify(metadata);
  for (const forbidden of ['providerGeneration', 'sha256', 'byteLength', 'vg-1', 'g-1', 'objk'])
    assert.equal(text.includes(forbidden), false, forbidden);
  assert.equal(metadata[1]?.width, 100);
});

void test('variant metadata is empty unless the asset is ready and delivery is enabled', () => {
  const ready = readyAsset();
  assert.equal(toVariantMetadata(ready).length, 2);
  assert.equal(toVariantMetadata({ ...ready, deliveryDisabled: true }).length, 0);
  for (const state of ['quarantined', 'blocked', 'deleting', 'deleted'] as const)
    assert.equal(toVariantMetadata({ ...ready, lifecycle: state }).length, 0, state);
});

void test('the manifest is bound to the pinned source generation and its profiles', () => {
  const asset = validating();
  const good = [variant('display', 1), variant('thumb', 2)];
  const first = verifyVariantManifest(asset, good, ['display', 'thumb']);
  assert.ok(first.ok);
  // Another source generation is a different input and never verifies.
  const other = {
    ...asset,
    sourceGenerationRef: { ...asset.sourceGenerationRef, providerGeneration: 'g-2' },
  } as MediaAsset;
  assert.equal(verifyVariantManifest(other, good, ['display', 'thumb']).ok, false);
  // An extra, non-mandatory profile changes the manifest but stays valid.
  const extra = verifyVariantManifest(asset, [...good, variant('large', 3)], ['display', 'thumb']);
  assert.ok(extra.ok);
  assert.notEqual(extra.revision, first.revision);
  assert.match(first.revision, /^[0-9a-f]{64}$/u);
});
