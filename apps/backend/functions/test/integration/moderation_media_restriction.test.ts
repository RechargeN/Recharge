// D2 §3 and §7 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): staff moderation
// restricts and restores one Media asset; Media accepts only an instruction that
// matches a recorded staff decision and lifts only the active restriction. T11.
import assert from 'node:assert/strict';
import test from 'node:test';

import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import type {
  MediaActorAuthorityPort,
  MediaRestrictionAuthority,
} from '../../src/modules/media/application/ports/actor_authority_port.js';
import {
  createReservedAsset,
  revocationEpochOf,
  type MediaAsset,
} from '../../src/modules/media/domain/media_asset.js';
import { FakeObjectStore } from '../../src/modules/media/infrastructure/fake_object_store.js';
import { InMemoryMediaRepository } from '../../src/modules/media/infrastructure/in_memory_media_repository.js';
import { ModerationService } from '../../src/modules/moderation/application/moderation_service.js';
import type {
  ContentModerationPort,
  StaffAuthorityPort,
} from '../../src/modules/moderation/application/ports.js';
import type {
  EnforcementReceipt,
  ModerationDecision,
} from '../../src/modules/moderation/domain/moderation.js';
import {
  ModerationRepositoryConflict,
  type ModerationIdempotencyRecord,
  type ModerationRepository,
  type ModerationTransaction,
} from '../../src/modules/moderation/domain/repositories.js';
import { MediaModerationAdapter } from '../../src/modules/moderation/infrastructure/media_moderation_adapter.js';
import { MediaRestrictionVerifier } from '../../src/modules/moderation/infrastructure/media_restriction_verifier.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';

const id = (n: number): EntityId => `01${String(n).padStart(24, '0')}` as EntityId;
const now = parseUtcInstant('2026-10-09T09:00:00.000Z');
const contentId = id(10);
const assetId = id(20);
const staff = { userId: 'staff-1', sessionId: 'session-1' };

/** TEST-ONLY in-memory moderation records with serialized transactions. */
class InMemoryModerationRepository implements ModerationRepository {
  readonly decisions = new Map<string, ModerationDecision>();
  readonly receipts = new Map<string, EnforcementReceipt>();
  readonly idempotency = new Map<string, ModerationIdempotencyRecord>();
  #tail: Promise<void> = Promise.resolve();

  async transact<T>(operation: (tx: ModerationTransaction) => T | Promise<T>): Promise<T> {
    let release: (() => void) | undefined;
    const previous = this.#tail;
    this.#tail = new Promise<void>((resolve) => (release = resolve));
    await previous;
    const decisions = new Map(this.decisions);
    const receipts = new Map(this.receipts);
    const idempotency = new Map(this.idempotency);
    try {
      const result = await operation({
        decision: (decisionId) => Promise.resolve(decisions.get(decisionId) ?? null),
        putDecision(decision) {
          if (decisions.has(decision.decisionId))
            throw new ModerationRepositoryConflict('already_exists');
          decisions.set(decision.decisionId, decision);
        },
        receipt: (decisionId) => Promise.resolve(receipts.get(decisionId) ?? null),
        putReceipt(receipt) {
          if (receipts.has(receipt.decisionId))
            throw new ModerationRepositoryConflict('already_exists');
          receipts.set(receipt.decisionId, receipt);
        },
        idempotency: (actorUserId, key) =>
          Promise.resolve(idempotency.get(`${actorUserId}|${key}`) ?? null),
        putIdempotency(record) {
          idempotency.set(`${record.actorUserId}|${record.idempotencyKey}`, record);
        },
        appendAudit() {},
      });
      for (const [key, value] of decisions) this.decisions.set(key, value);
      for (const [key, value] of receipts) this.receipts.set(key, value);
      for (const [key, value] of idempotency) this.idempotency.set(key, value);
      return result;
    } finally {
      release?.();
    }
  }

  recent() {
    return Promise.resolve([]);
  }
}

function readyAsset(n: number, binding = true): MediaAsset {
  return {
    ...createReservedAsset({
      assetId: id(n),
      ownerSubjectId: id(2),
      ...(binding
        ? { entityBinding: { domain: 'content', entityId: contentId, purpose: 'contentMedia' } }
        : {}),
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'publicDerived',
      policyRevision: 'policy-test-1',
      objectKeyHandle: `objk:test-${String(n)}-aaaaaaaaaaaaaaaaaa`,
      nowUtc: now,
    }),
    lifecycle: 'ready',
  };
}

async function harness() {
  const moderationRepository = new InMemoryModerationRepository();
  const mediaRepository = new InMemoryMediaRepository();
  for (const asset of [readyAsset(20), readyAsset(21, false), readyAsset(22)])
    await mediaRepository.transact((tx) => tx.putAsset(asset, 0));
  const authority: MediaActorAuthorityPort = {
    evaluate: () => Promise.resolve({ allowed: true, authorityRevision: 1 }),
  };
  const restrictionAuthority: MediaRestrictionAuthority = new MediaRestrictionVerifier(
    moderationRepository,
  );
  const deletion = new MediaDeletionService({
    repository: mediaRepository,
    authority,
    restrictionAuthority,
    references: { isReferenced: () => Promise.resolve(true) },
    objectStore: new FakeObjectStore(),
    clock: { now: () => new Date(now) },
    ids: { newId: () => id(900) },
  });
  const staffAuthority: StaffAuthorityPort = { evaluate: () => Promise.resolve({ allowed: true }) };
  const content: ContentModerationPort = {
    reviewQueue: () => Promise.resolve([]),
    submission: () => Promise.resolve(null),
    publication: () => Promise.resolve(null),
    enforce: () => Promise.reject(new Error('a Media decision never reaches Content')),
  };
  let serial = 0;
  const service = new ModerationService({
    repository: moderationRepository,
    staff: staffAuthority,
    content,
    media: new MediaModerationAdapter(mediaRepository, deletion),
    clock: { now: () => new Date(now) },
    newId: () => `decision-${String(++serial)}`,
  });
  const asset = async (n = 20) => {
    const stored = await mediaRepository.transact((tx) => tx.asset(id(n)));
    assert.ok(stored);
    return stored;
  };
  return { service, deletion, mediaRepository, moderationRepository, asset };
}

const decide = (
  h: Awaited<ReturnType<typeof harness>>,
  action: 'restrict_media' | 'restore_media',
  options: { readonly restores?: string; readonly key?: string; readonly asset?: string } = {},
) =>
  h.service.decide(staff, {
    schemaVersion: 1,
    action,
    idempotencyKey: options.key ?? `key-${action}-${Math.random().toString(36).slice(2, 10)}`,
    reason: 'unsafe cover image',
    target: { assetId: options.asset ?? assetId },
    ...(options.restores === undefined ? {} : { restoresDecisionId: options.restores }),
  });

function receipt(result: Awaited<ReturnType<ModerationService['decide']>>) {
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  if (result.kind !== 'succeeded') throw new Error('refused');
  return result.data;
}

void test('T11: a staff decision restricts the asset through Media; its restore lifts it', async () => {
  const h = await harness();
  const restricted = receipt(await decide(h, 'restrict_media', { key: 'restrict-key-1' }));
  assert.equal(restricted.receipt.outcome, 'applied');
  assert.equal(restricted.receipt.contentId, contentId, 'the Content binding of the asset');
  assert.equal(restricted.decision.target.assetId, assetId);
  const after = await h.asset();
  assert.equal(after.deliveryDisabled, true);
  assert.equal(after.restrictionDecisionRef, restricted.decision.decisionId);
  assert.equal(revocationEpochOf(after), 1);
  // The same key resumes the same decision: no second restriction.
  const replay = receipt(await decide(h, 'restrict_media', { key: 'restrict-key-1' }));
  assert.equal(replay.decision.decisionId, restricted.decision.decisionId);
  assert.equal(revocationEpochOf(await h.asset()), 1);
  const restored = receipt(
    await decide(h, 'restore_media', { restores: restricted.decision.decisionId }),
  );
  assert.equal(restored.receipt.outcome, 'applied');
  const lifted = await h.asset();
  assert.equal(lifted.deliveryDisabled, false);
  assert.equal(revocationEpochOf(lifted), 1, 'the marker stays');
});

void test('T11: a newer restriction replaces the older one; restoring the older is refused', async () => {
  const h = await harness();
  const first = receipt(await decide(h, 'restrict_media'));
  const second = receipt(await decide(h, 'restrict_media'));
  assert.equal(revocationEpochOf(await h.asset()), 2);
  const stale = receipt(await decide(h, 'restore_media', { restores: first.decision.decisionId }));
  assert.equal(stale.receipt.outcome, 'refused');
  assert.equal(stale.receipt.refusalCode, 'stale_revision');
  assert.equal((await h.asset()).deliveryDisabled, true);
  receipt(await decide(h, 'restore_media', { restores: second.decision.decisionId }));
  assert.equal((await h.asset()).deliveryDisabled, false);
});

void test('T11: forged or foreign instructions change nothing', async () => {
  const h = await harness();
  const command = (decisionRef: string, restricted: boolean) => ({
    schemaVersion: 1,
    commandType: 'applyRestriction',
    idempotencyKey: `forged-${decisionRef}-${String(restricted)}`,
    payload: { assetId, decisionRef, restricted },
  });
  // No recorded decision at all.
  assert.deepEqual(await h.deletion.applyRestriction(command('decision-404', true)), {
    kind: 'rejected',
    code: 'capability_denied',
  });
  // A real decision, but for another asset, or used for the opposite action.
  const other = receipt(await decide(h, 'restrict_media', { asset: id(22) }));
  assert.deepEqual(await h.deletion.applyRestriction(command(other.decision.decisionId, true)), {
    kind: 'rejected',
    code: 'capability_denied',
  });
  assert.equal((await h.asset()).deliveryDisabled, false);
  const real = receipt(await decide(h, 'restrict_media'));
  assert.deepEqual(await h.deletion.applyRestriction(command(real.decision.decisionId, false)), {
    kind: 'rejected',
    code: 'capability_denied',
  });
  // A tampered stored decision no longer matches its attestation.
  const stored = h.moderationRepository.decisions.get(real.decision.decisionId);
  assert.ok(stored);
  h.moderationRepository.decisions.set(real.decision.decisionId, { ...stored, reason: 'edited' });
  assert.deepEqual(
    await h.deletion.applyRestriction({
      ...command(real.decision.decisionId, true),
      idempotencyKey: 'forged-tampered',
    }),
    { kind: 'rejected', code: 'capability_denied' },
  );
});

void test('T11: the command names exactly one asset and a restore a recorded restriction', async () => {
  const h = await harness();
  const invalid = { kind: 'rejected', code: 'invalid_contract' };
  const base = {
    schemaVersion: 1,
    action: 'restrict_media',
    idempotencyKey: 'key-invalid-1',
    reason: 'unsafe cover image',
  };
  assert.deepEqual(
    await h.service.decide(staff, { ...base, target: { assetId, contentId } }),
    invalid,
  );
  assert.deepEqual(await h.service.decide(staff, { ...base, target: {} }), invalid);
  assert.deepEqual(
    await h.service.decide(staff, { ...base, action: 'restore_media', target: { assetId } }),
    invalid,
  );
  assert.deepEqual(
    await h.service.decide(staff, { ...base, action: 'restrict', target: { assetId } }),
    invalid,
  );
  assert.deepEqual(await decide(h, 'restore_media', { restores: 'decision-404' }), {
    kind: 'rejected',
    code: 'target_not_found',
  });
  assert.deepEqual(await decide(h, 'restrict_media', { asset: id(99) }), {
    kind: 'rejected',
    code: 'target_not_found',
  });
  // An asset bound to no Content is not a target of this path.
  assert.deepEqual(await decide(h, 'restrict_media', { asset: id(21) }), {
    kind: 'rejected',
    code: 'target_not_found',
  });
});
