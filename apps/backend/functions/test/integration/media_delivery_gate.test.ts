// D2 §4 and §10 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): the delivery gate
// decides every request again from the publication and Media's own record; a
// restriction committed before the last check refuses the request at once,
// whatever Content and Catalog still say. T1, T3 (gate side), T12, T14 (lock).
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import type { MediaVariantRefV1 } from '../../src/contracts/media_v1.js';
import {
  MediaDeliveryGate,
  type DeliveredVariant,
} from '../../src/modules/media/application/media_delivery_gate.js';
import type {
  PublishedMediaPin,
  PublishedMediaPort,
} from '../../src/modules/media/application/ports/published_media_port.js';
import type { MediaResult } from '../../src/modules/media/domain/failures.js';
import {
  createReservedAsset,
  placeDeletionHold,
  withRestriction,
  type MediaAsset,
} from '../../src/modules/media/domain/media_asset.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

const now = parseUtcInstant('2026-10-09T09:00:00.000Z');
const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const contentId = id(10);
const assetId = id(20);
const display = Buffer.from('display variant bytes (synthetic, not an image)');
const thumb = Buffer.from('thumb variant bytes');
const sha = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

function variant(n: number, profile: string, bytes: Buffer): MediaVariantRefV1 {
  return {
    variantId: id(n),
    profile,
    format: 'image/jpeg',
    providerGeneration: `vg-${profile}`,
    sha256: sha(bytes),
    byteLength: bytes.length,
    transformProfileRevision: 'tp-test-1',
    sourceProviderGeneration: 'g-1',
  };
}

function readyAsset(): MediaAsset {
  return {
    ...createReservedAsset({
      assetId,
      ownerSubjectId: id(2),
      publisherRef: { type: 'page', id: id(3) },
      entityBinding: { domain: 'content', entityId: contentId, purpose: 'contentMedia' },
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'publicDerived',
      policyRevision: 'policy-test-1',
      objectKeyHandle: 'objk:test',
      nowUtc: now,
    }),
    lifecycle: 'ready',
    sourceGenerationRef: {
      providerGeneration: 'g-1',
      byteLength: 10,
      verifiedMediaType: 'image/jpeg',
      sha256: 'a'.repeat(64),
      validationProfileRevision: 'vp-test-1',
    },
    variantRefs: [variant(31, 'display', display), variant(32, 'thumb', thumb)],
    variantManifestRevision: 'manifest-1',
  };
}

const pinFor = (overrides: Partial<PublishedMediaPin> = {}): PublishedMediaPin => ({
  contentId,
  pointerRevision: 3,
  publishedRevisionId: id(11),
  sourceGeneration: 'g-1',
  variantManifestRevision: 'manifest-1',
  revocationEpoch: 0,
  ...overrides,
});

class Published implements PublishedMediaPort {
  pins: (PublishedMediaPin | null)[] = [];
  fallback: PublishedMediaPin | null = pinFor();
  calls = 0;
  /** Runs inside the call; a test can prove the gate holds no Media lock here. */
  onCall: (() => Promise<void>) | undefined;
  async deliverablePin(): Promise<PublishedMediaPin | null> {
    this.calls += 1;
    await this.onCall?.();
    return this.pins.length > 0 ? (this.pins.shift() ?? null) : this.fallback;
  }
}

async function harness(asset: MediaAsset = readyAsset()) {
  const repository = new InMemoryMediaRepository();
  await repository.transact((tx) => tx.putAsset(asset, 0));
  const objects = new FakeObjectStore();
  objects.putVariantBytes(id(31), 'vg-display', display);
  objects.putVariantBytes(id(32), 'vg-thumb', thumb);
  const published = new Published();
  const gate = new MediaDeliveryGate({ repository, published, objects, maxBytes: 1024 });
  const change = (next: (asset: MediaAsset) => MediaAsset) =>
    repository.transact(async (tx) => {
      const stored = await tx.asset(assetId);
      assert.ok(stored);
      tx.putAsset(next(stored), stored.revision);
    });
  return { repository, objects, published, gate, change };
}

const request = (profile = 'display') => ({ contentId, assetId, profile });
const notFound = { kind: 'rejected', code: 'not_found' } as const;

function delivered(result: MediaResult<DeliveredVariant>): DeliveredVariant {
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  if (result.kind !== 'succeeded') throw new Error('refused');
  return result.data;
}

void test('T1: the bytes of the pinned public variant, matched against the manifest', async () => {
  const h = await harness();
  const display1 = delivered(await h.gate.deliver(request()));
  assert.ok(display1.bytes.equals(display));
  assert.equal(display1.sha256, sha(display));
  assert.equal(display1.byteLength, display.length);
  assert.equal(display1.format, 'image/jpeg');
  assert.ok(delivered(await h.gate.deliver(request('thumb'))).bytes.equals(thumb));
  assert.deepEqual(await h.gate.deliver(request('original')), notFound);
  // Twice per delivered request (steps 2 and 5), once for the refused profile.
  assert.equal(h.published.calls, 5);
});

void test('the publication decides: no pin, a pin for another Content or a moved pin', async () => {
  const h = await harness();
  h.published.fallback = null;
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  h.published.fallback = pinFor({ contentId: id(99) });
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  h.published.fallback = pinFor({ sourceGeneration: 'g-2' });
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  h.published.fallback = pinFor({ variantManifestRevision: 'manifest-0' });
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  // A failing owning domain is a refusal, never a thrown error.
  h.published.fallback = pinFor();
  h.published.onCall = () => Promise.reject(new Error('content unreachable'));
  assert.deepEqual(await h.gate.deliver(request()), notFound);
});

void test('T2/T3: a restriction refuses the next request at once and its lift does not reopen it', async () => {
  const h = await harness();
  delivered(await h.gate.deliver(request()));
  await h.change((asset) => withRestriction(asset, { restricted: true, decisionRef: 'd-1' }, now));
  // Content and Catalog are untouched here: the pin still says epoch 0.
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  await h.change((asset) =>
    withRestriction(asset, { restricted: false, restoresDecisionRef: 'd-1' }, now),
  );
  // Media is `ready` again, but the confirmed epoch no longer matches.
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  // Only a publisher's new confirmation (epoch 1) reopens delivery.
  h.published.fallback = pinFor({ revocationEpoch: 1 });
  delivered(await h.gate.deliver(request()));
});

void test('Media states that never deliver: hold, deletion, other binding, private class', async () => {
  for (const make of [
    (asset: MediaAsset) =>
      placeDeletionHold(
        asset,
        { holdId: 'h-1', expiresAtUtc: parseUtcInstant('2026-10-09T09:10:00.000Z') },
        now,
      ),
    (asset: MediaAsset): MediaAsset => ({
      ...asset,
      lifecycle: 'deleting',
      deliveryDisabled: true,
    }),
    (asset: MediaAsset): MediaAsset => ({
      ...asset,
      entityBinding: { domain: 'content', entityId: id(99), purpose: 'contentMedia' },
    }),
    (asset: MediaAsset): MediaAsset => ({ ...asset, visibilityClass: 'private' }),
  ]) {
    const h = await harness(make(readyAsset()));
    assert.deepEqual(await h.gate.deliver(request()), notFound);
  }
  const absent = await harness();
  absent.published.fallback = pinFor();
  assert.deepEqual(
    await absent.gate.deliver({ contentId, assetId: id(77), profile: 'display' }),
    notFound,
  );
});

void test('bytes must be the pinned generation, the manifest hash and within the bound', async () => {
  const tampered = await harness();
  tampered.objects.putVariantBytes(id(31), 'vg-display', Buffer.from('other bytes'));
  assert.deepEqual(await tampered.gate.deliver(request()), notFound);
  const regenerated = await harness();
  regenerated.objects.putVariantBytes(id(31), 'vg-display-2', display);
  assert.deepEqual(await regenerated.gate.deliver(request()), notFound);
  const missing = await harness();
  missing.objects.variants.delete(id(31));
  assert.deepEqual(await missing.gate.deliver(request()), notFound);
  const bounded = await harness();
  const small = new MediaDeliveryGate({
    repository: bounded.repository,
    published: bounded.published,
    objects: bounded.objects,
    maxBytes: 4,
  });
  assert.deepEqual(await small.deliver(request()), notFound);
});

void test('T12/W1: a restriction committed while the bytes are read refuses this request', async () => {
  const h = await harness();
  h.objects.onReadVariant = async () => {
    h.objects.onReadVariant = undefined;
    await h.change((asset) =>
      withRestriction(asset, { restricted: true, decisionRef: 'd-1' }, now),
    );
  };
  assert.deepEqual(await h.gate.deliver(request()), notFound);
});

void test('T12/W1: after the last check the response goes out; the next request is refused', async () => {
  const h = await harness();
  const result = await h.gate.deliver(request());
  // Window W1: the restriction lands after step 6 — this one response is out.
  await h.change((asset) => withRestriction(asset, { restricted: true, decisionRef: 'd-1' }, now));
  delivered(result);
  assert.deepEqual(await h.gate.deliver(request()), notFound);
});

void test('T12/W2: a publication change between steps 2 and 5 refuses the request', async () => {
  const h = await harness();
  h.published.pins = [pinFor(), pinFor({ pointerRevision: 4 })];
  assert.deepEqual(await h.gate.deliver(request()), notFound);
  h.published.pins = [pinFor(), null];
  assert.deepEqual(await h.gate.deliver(request()), notFound);
});

void test('T14: the owning domain is asked while no Media transaction is held', async () => {
  const h = await harness();
  // The in-memory repository serializes transactions: a call made under a Media
  // lock that opens a Media transaction itself would never finish.
  h.published.onCall = async () => {
    const opened = h.repository.transact(() => 'free');
    const timeout = new Promise<string>((resolve) => setTimeout(() => resolve('locked'), 500));
    assert.equal(await Promise.race([opened, timeout]), 'free');
  };
  delivered(await h.gate.deliver(request()));
});
