// D2 §5 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md): Content's reaction to late
// Media restriction or deletion, over the real Content service and the
// in-memory repository. Media is a scripted world of states, epochs and facts.
// T3, T4, T5, T6, T7, T9, the R1 half of T10 and the lock half of T14.
import assert from 'node:assert/strict';
import test from 'node:test';

import type { ContentEffectV1, MediaAttachmentV1 } from '../../src/contracts/content_v1.js';
import {
  ContentMediaAvailability,
  mediaAvailabilityTestOnlyConfig,
} from '../../src/modules/content/application/content_media_availability.js';
import { ContentMediaScope } from '../../src/modules/content/application/content_media_scope.js';
import { ContentPublicationService } from '../../src/modules/content/application/content_publication_service.js';
import type {
  ContentFactSource,
  MediaAvailabilityPort,
  MediaFact,
  MediaFactSource,
} from '../../src/modules/content/application/ports/media_availability_port.js';
import type {
  MediaReadiness,
  MediaReadinessPort,
} from '../../src/modules/content/application/ports/media_readiness_port.js';
import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import type {
  AttachedMediaState,
  PublicationPointer,
} from '../../src/modules/content/domain/publication_pointer.js';
import type {
  ContentRepository,
  ContentTransaction,
  FeedPosition,
} from '../../src/modules/content/domain/repositories.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import type { EntityId } from '../../src/shared/ids.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import { commands, newId, servicePorts } from '../support/content_repository_scenarios.js';

const ordered = <T extends FeedPosition>(items: readonly T[], after: FeedPosition | null) =>
  [...items]
    .sort((left, right) =>
      left.occurredAtUtc === right.occurredAtUtc
        ? left.effectId < right.effectId
          ? -1
          : 1
        : left.occurredAtUtc < right.occurredAtUtc
          ? -1
          : 1,
    )
    .filter(
      (item) =>
        after === null ||
        item.occurredAtUtc > after.occurredAtUtc ||
        (item.occurredAtUtc === after.occurredAtUtc && item.effectId > after.effectId),
    );

/** Scripted Media: current states and epochs, and the facts it committed. */
class MediaWorld implements MediaReadinessPort, MediaAvailabilityPort, MediaFactSource {
  readonly states = new Map<string, AttachedMediaState>();
  readonly facts: MediaFact[] = [];
  /** T7: runs right after Content took its evidence, before its commit. */
  afterEvidence: (() => void) | undefined;
  /** Evidence requests to let pass before `afterEvidence` runs (submit asks too). */
  skipEvidence = 0;
  /** Number of next availability answers that fail (Media unreachable). */
  failAvailability = 0;
  /** Runs inside every availability answer (T14 lock probe). */
  onAvailability: (() => Promise<void>) | undefined;

  constructor(private readonly clock: ServerClock) {}

  attach(assetId: EntityId): MediaAttachmentV1 {
    this.states.set(assetId, {
      assetId,
      state: 'deliverable',
      revocationEpoch: 0,
      sourceGeneration: `g-${assetId}`,
      variantManifestRevision: `m-${assetId}`,
    });
    return {
      assetId,
      sourceGeneration: `g-${assetId}`,
      variantManifestRevision: `m-${assetId}`,
      purpose: 'contentMedia',
    };
  }

  check(): Promise<MediaReadiness> {
    const assets = [...this.states.values()];
    const blocked = assets.find((item) => item.state !== 'deliverable');
    const evidence: MediaReadiness =
      blocked === undefined
        ? {
            ready: true,
            mediaRevision: 'media-1',
            attachments: assets.map((item) => ({
              assetId: item.assetId as EntityId,
              sourceGeneration: item.sourceGeneration ?? '',
              variantManifestRevision: item.variantManifestRevision ?? '',
              purpose: 'contentMedia',
            })),
            confirmations: assets.map((item) => ({
              assetId: item.assetId as EntityId,
              revocationEpoch: item.revocationEpoch,
            })),
          }
        : { ready: false, reason: blocked.state === 'deleted' ? 'deleted' : 'restricted' };
    if (this.skipEvidence > 0) this.skipEvidence -= 1;
    else {
      this.afterEvidence?.();
      this.afterEvidence = undefined;
    }
    return Promise.resolve(evidence);
  }

  async availability(assetIds: readonly string[]): Promise<readonly AttachedMediaState[]> {
    await this.onAvailability?.();
    if (this.failAvailability > 0) {
      this.failAvailability -= 1;
      throw new Error('media unreachable');
    }
    return assetIds.map(
      (assetId) => this.states.get(assetId) ?? { assetId, state: 'absent', revocationEpoch: 0 },
    );
  }

  effectsAfter(after: FeedPosition | null, limit: number): Promise<readonly MediaFact[]> {
    return Promise.resolve(ordered(this.facts, after).slice(0, limit));
  }

  #change(assetId: string, patch: Partial<AttachedMediaState>, type: string, bump: boolean) {
    const current = this.states.get(assetId);
    assert.ok(current);
    const next = {
      ...current,
      ...patch,
      revocationEpoch: current.revocationEpoch + (bump ? 1 : 0),
    };
    this.states.set(assetId, next);
    const fact: MediaFact = {
      effectId: `${assetId}:${type}:${String(this.facts.length + 1)}`,
      type,
      assetId,
      assetRevision: this.facts.length + 1,
      occurredAtUtc: this.clock.now().toISOString(),
    };
    this.facts.push(fact);
    return fact;
  }

  restrict(assetId: string) {
    return this.#change(assetId, { state: 'restricted' }, 'MediaDeliveryDisabled', true);
  }
  lift(assetId: string) {
    return this.#change(assetId, { state: 'deliverable' }, 'MediaDeliveryRestored', false);
  }
  remove(assetId: string) {
    return this.#change(assetId, { state: 'deleted' }, 'MediaAssetDeleted', true);
  }
}

/** Committed Content facts of the in-memory repository, in feed order. */
class ContentFacts implements ContentFactSource {
  constructor(private readonly repository: InMemoryContentRepository) {}
  effectsAfter(after: FeedPosition | null, limit: number): Promise<readonly ContentEffectV1[]> {
    return Promise.resolve(ordered(this.repository.snapshot().effects, after).slice(0, limit));
  }
}

async function data<T>(promise: Promise<{ kind: string; data?: unknown; code?: string }>) {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', `unexpected ${result.kind}:${String(result.code)}`);
  return result.data as T;
}

function world(options: { readonly repository?: ContentRepository } = {}) {
  let ms = Date.parse('2026-10-09T10:00:00.000Z');
  const clock: ServerClock = { now: () => new Date((ms += 1000)) };
  const memory = new InMemoryContentRepository();
  const repository = options.repository ?? memory;
  const media = new MediaWorld(clock);
  const ports = servicePorts();
  const service = new ContentPublicationService({ repository, ...ports, media, clock });
  const availability = new ContentMediaAvailability({
    repository,
    media,
    mediaFacts: media,
    contentFacts: new ContentFacts(memory),
    clock,
  });
  const scope = new ContentMediaScope({ repository, eligibility: ports.eligibility });
  const owner = newId();
  const actor: ContentActor = { userId: owner, sessionId: newId() };
  const c = commands(owner);
  const asset = newId();
  media.attach(asset);
  async function publish() {
    const draft = await data<{ draftId: string; contentId: string }>(
      service.execute(actor, c.create()),
    );
    const submission = await data<{ submissionId: string }>(
      service.execute(actor, c.submit(draft.draftId, 1)),
    );
    const revision = await data<{ publishedRevisionId: string }>(
      service.execute(actor, c.publish(submission.submissionId, 0)),
    );
    return { contentId: draft.contentId, publishedRevisionId: revision.publishedRevisionId };
  }
  const pointer = (contentId: string) =>
    repository.transact(async (tx) => {
      const found = await tx.pointer(contentId);
      assert.ok(found);
      return found;
    });
  const reactivate = async (contentId: string, publishedRevisionId: string) => {
    const current = await pointer(contentId);
    return service.execute(actor, c.activate(contentId, publishedRevisionId, current.revision));
  };
  const effects = (contentId: string) =>
    memory.snapshot().effects.filter((item) => item.contentId === contentId);
  return {
    repository,
    memory,
    media,
    service,
    availability,
    scope,
    asset,
    publish,
    pointer,
    reactivate,
    effects,
  };
}

const suppressedOf = (pointer: PublicationPointer) =>
  (pointer.mediaSuppression ?? []).map((item) => [item.assetId, item.reason]);

void test('T3: restricted and lifted while Content was not running: suppressed, then confirmed again by the publisher only', async () => {
  const w = world();
  const { contentId, publishedRevisionId } = await w.publish();
  const published = await w.pointer(contentId);
  assert.deepEqual(published.mediaConfirmations, [{ assetId: w.asset, revocationEpoch: 0 }]);
  assert.equal((await w.scope.deliverablePin({ contentId, assetId: w.asset }))?.revocationEpoch, 0);
  w.media.restrict(w.asset);
  w.media.lift(w.asset);
  // Nothing ran yet: Content still pins epoch 0 (the delivery gate refuses on the
  // epoch, see media_delivery_gate.test.ts).
  assert.equal((await w.pointer(contentId)).revision, published.revision);
  const report = await w.availability.deliverMediaEffects();
  assert.equal(report.stoppedAt, null);
  assert.equal(report.suppressed, 1);
  const suppressed = await w.pointer(contentId);
  assert.deepEqual(suppressedOf(suppressed), [[w.asset, 'revoked']]);
  assert.equal(suppressed.visibility, 'visible');
  assert.equal(suppressed.currentPublishedRevisionId, publishedRevisionId);
  assert.equal(await w.scope.deliverablePin({ contentId, assetId: w.asset }), null);
  const fact = w.effects(contentId).at(-1);
  assert.equal(fact?.kind, 'ContentMediaAvailabilityChanged');
  assert.deepEqual(fact?.suppressedMediaIds, [w.asset]);
  // MediaDeliveryRestored did not lift anything; the publisher confirms again.
  const confirmed = await data<PublicationPointer>(w.reactivate(contentId, publishedRevisionId));
  assert.equal(confirmed.mediaSuppression, undefined);
  assert.deepEqual(confirmed.mediaConfirmations, [{ assetId: w.asset, revocationEpoch: 1 }]);
  assert.equal(confirmed.currentPublishedRevisionId, publishedRevisionId);
  const restored = w.effects(contentId).at(-1);
  assert.equal(restored?.kind, 'ContentMediaAvailabilityChanged');
  assert.equal(restored?.suppressedMediaIds, undefined);
  assert.equal((await w.scope.deliverablePin({ contentId, assetId: w.asset }))?.revocationEpoch, 1);
  // A second activation with nothing left to confirm is a conflict, without a fact.
  const before = w.effects(contentId).length;
  assert.deepEqual(await w.reactivate(contentId, publishedRevisionId), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  assert.equal(w.effects(contentId).length, before);
});

void test('T3: the publisher cannot confirm while Media is still restricted', async () => {
  const w = world();
  const { contentId, publishedRevisionId } = await w.publish();
  w.media.restrict(w.asset);
  await w.availability.deliverMediaEffects();
  assert.deepEqual(await w.reactivate(contentId, publishedRevisionId), {
    kind: 'rejected',
    code: 'media_not_ready',
  });
  assert.deepEqual(suppressedOf(await w.pointer(contentId)), [[w.asset, 'revoked']]);
});

void test('T4: duplicates and any order of Media facts, before and after the confirmation', async () => {
  const w = world();
  const { contentId, publishedRevisionId } = await w.publish();
  const disabled = w.media.restrict(w.asset);
  const restored = w.media.lift(w.asset);
  // Delivered late and in reverse order: the decision reads Media now.
  w.media.facts.splice(0, w.media.facts.length, restored, disabled);
  await w.availability.deliverMediaEffects();
  await w.availability.deliverMediaEffects();
  const revisions = () => w.effects(contentId).map((item) => item.pointerRevision);
  assert.deepEqual(revisions(), [1, 2]);
  await data(w.reactivate(contentId, publishedRevisionId));
  // The same facts again, redelivered after the confirmation: the confirmed epoch
  // equals Media's, so processing them suppresses nothing.
  const late = '2026-10-09T23:00:00.000Z';
  w.media.facts.push(
    { ...disabled, effectId: `${disabled.effectId}:again`, occurredAtUtc: late },
    { ...restored, effectId: `${restored.effectId}:again`, occurredAtUtc: late },
  );
  const report = await w.availability.deliverMediaEffects();
  assert.equal(report.processed, 2);
  assert.equal(report.suppressed, 0);
  // Nothing after the checkpoint: a repeated run processes nothing.
  assert.equal((await w.availability.deliverMediaEffects()).processed, 0);
  // A checkpoint that went back (lost write) replays the feed: receipts dedupe it.
  await w.repository.transact((tx) =>
    tx.putMediaAvailabilityStatus({
      feed: 'mediaEffects',
      checkpoint: null,
      updatedAtUtc: '2026-10-09T23:30:00.000Z',
    }),
  );
  const replay = await w.availability.deliverMediaEffects();
  assert.equal(replay.deduped, 4);
  assert.equal(replay.processed, 0);
  assert.deepEqual(revisions(), [1, 2, 3]);
  assert.deepEqual(revisions(), [1, 2, 3]);
  assert.equal((await w.pointer(contentId)).mediaSuppression, undefined);
});

void test('T5: a lost worker repeats the reconciliation, which changes nothing the second time', async () => {
  // Before the commit: Media unreachable stops the run before the fact.
  const early = world();
  const first = await early.publish();
  early.media.restrict(early.asset);
  early.media.failAvailability = 1;
  const stopped = await early.availability.deliverMediaEffects();
  assert.equal(stopped.stoppedAt?.code, 'media_unavailable');
  assert.equal(stopped.checkpoint, null);
  assert.equal((await early.pointer(first.contentId)).mediaSuppression, undefined);
  await early.availability.deliverMediaEffects();
  assert.deepEqual(suppressedOf(await early.pointer(first.contentId)), [[early.asset, 'revoked']]);

  // After the commit of the suppression, before the receipt and checkpoint.
  const memory = new InMemoryContentRepository();
  let crashAfterSuppression = true;
  const crashing: ContentRepository = {
    async transact<T>(operation: (tx: ContentTransaction) => T | Promise<T>): Promise<T> {
      let suppressed = false;
      const result = await memory.transact((tx) =>
        operation({
          ...tx,
          effects: tx.effects,
          putPointer(pointer, expected) {
            if ((pointer.mediaSuppression ?? []).length > 0) suppressed = true;
            tx.putPointer(pointer, expected);
          },
        }),
      );
      if (suppressed && crashAfterSuppression) {
        crashAfterSuppression = false;
        throw new Error('worker lost after the commit');
      }
      return result;
    },
  };
  const late = world({ repository: crashing });
  const second = await late.publish();
  late.media.restrict(late.asset);
  await assert.rejects(late.availability.deliverMediaEffects(), /worker lost/u);
  const report = await late.availability.deliverMediaEffects();
  assert.equal(report.stoppedAt, null);
  assert.equal(report.processed, 1);
  assert.equal(report.suppressed, 0, 'the second run found it done');
  const kinds = memory
    .snapshot()
    .effects.filter((item) => item.contentId === second.contentId)
    .map((item) => item.kind);
  assert.deepEqual(kinds, ['ContentPublished', 'ContentMediaAvailabilityChanged']);
});

void test('T6: a late run after several changes reaches the same state as a prompt one', async () => {
  const w = world();
  const { contentId } = await w.publish();
  w.media.restrict(w.asset);
  w.media.lift(w.asset);
  w.media.restrict(w.asset);
  w.media.lift(w.asset);
  const report = await w.availability.deliverMediaEffects();
  assert.equal(report.processed, 4);
  assert.equal(report.suppressed, 1);
  const pointer = await w.pointer(contentId);
  assert.deepEqual(pointer.mediaSuppression, [
    { assetId: w.asset, reason: 'revoked', observedEpoch: 2 },
  ]);
});

void test('T7: a restriction between evidence and commit is caught by the Content fact check', async () => {
  const w = world();
  // Submit takes evidence first; the restriction lands right after the publish evidence.
  w.media.skipEvidence = 1;
  w.media.afterEvidence = () => w.media.restrict(w.asset);
  const { contentId, publishedRevisionId } = await w.publish();
  // The publication confirmed epoch 0, but Media is already at epoch 1.
  assert.deepEqual((await w.pointer(contentId)).mediaConfirmations, [
    { assetId: w.asset, revocationEpoch: 0 },
  ]);
  const report = await w.availability.deliverContentEffects();
  assert.equal(report.suppressed, 1);
  assert.deepEqual(suppressedOf(await w.pointer(contentId)), [[w.asset, 'revoked']]);
  // The same window around a publisher's confirmation.
  w.media.lift(w.asset);
  w.media.afterEvidence = () => w.media.restrict(w.asset);
  await data(w.reactivate(contentId, publishedRevisionId));
  assert.equal((await w.pointer(contentId)).mediaSuppression, undefined);
  await w.availability.deliverContentEffects();
  assert.deepEqual(suppressedOf(await w.pointer(contentId)), [[w.asset, 'revoked']]);
  // The check of its own fact changes nothing more.
  const settled = await w.availability.deliverContentEffects();
  assert.equal(settled.suppressed, 0);
});

void test('T9: a deleted asset is suppressed for good: the publisher cannot confirm it', async () => {
  const w = world();
  const { contentId, publishedRevisionId } = await w.publish();
  w.media.remove(w.asset);
  await w.availability.deliverMediaEffects();
  assert.deepEqual(suppressedOf(await w.pointer(contentId)), [[w.asset, 'deleted']]);
  assert.deepEqual(await w.reactivate(contentId, publishedRevisionId), {
    kind: 'rejected',
    code: 'media_not_ready',
  });
  // A record Media no longer has at all is the same.
  const gone = world();
  const second = await gone.publish();
  gone.media.states.delete(gone.asset);
  assert.equal(await gone.availability.reconcileContent(second.contentId), 'suppressed');
  assert.deepEqual(suppressedOf(await gone.pointer(second.contentId)), [[gone.asset, 'deleted']]);
});

void test('a deletion hold alone suppresses nothing; an unknown Content has no publication', async () => {
  const w = world();
  const { contentId } = await w.publish();
  const state = w.media.states.get(w.asset);
  assert.ok(state);
  w.media.states.set(w.asset, { ...state, state: 'held' });
  assert.equal(await w.availability.reconcileContent(contentId), 'unchanged');
  w.media.states.set(w.asset, state);
  w.media.restrict(w.asset);
  assert.equal(await w.availability.reconcileContent('unknown-content'), 'no_publication');
  assert.equal(await w.availability.reconcileContent(contentId), 'suppressed');
  assert.equal(await w.availability.reconcileContent(contentId), 'unchanged');
});

void test('R1: the sweep catches a fact the feed never delivered', async () => {
  const w = world();
  const { contentId } = await w.publish();
  const other = await w.publish();
  w.media.restrict(w.asset);
  // The fact is lost (W5); only the current state remains.
  w.media.facts.length = 0;
  assert.equal((await w.availability.deliverMediaEffects()).processed, 0);
  const report = await w.availability.sweep();
  assert.equal(report.checked, 2);
  assert.equal(report.suppressed, 2);
  assert.deepEqual(report.unavailable, []);
  assert.deepEqual(suppressedOf(await w.pointer(contentId)), [[w.asset, 'revoked']]);
  assert.deepEqual(suppressedOf(await w.pointer(other.contentId)), [[w.asset, 'revoked']]);
  assert.equal((await w.availability.sweep()).suppressed, 0);
  assert.ok(mediaAvailabilityTestOnlyConfig.batchSize > 0);
});

void test('T14: Media is asked while no Content transaction is held', async () => {
  const w = world();
  const { contentId } = await w.publish();
  w.media.restrict(w.asset);
  w.media.onAvailability = async () => {
    const opened = w.repository.transact(() => 'free');
    const timeout = new Promise<string>((resolve) => setTimeout(() => resolve('locked'), 500));
    assert.equal(await Promise.race([opened, timeout]), 'free');
  };
  assert.equal(await w.availability.reconcileContent(contentId), 'suppressed');
});
