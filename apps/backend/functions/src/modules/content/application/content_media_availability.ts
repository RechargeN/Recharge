import type { ServerClock } from '../../../shared/server_clock.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { ContentRepositoryConflict } from '../domain/failures.js';
import {
  contentEffect,
  mediaSuppressionOf,
  mediaSuppressionsFor,
  suppressMedia,
  type AttachedMediaState,
} from '../domain/publication_pointer.js';
import { canonicalJson, sha256Hex } from '../domain/published_revision.js';
import type {
  ContentRepository,
  FeedPosition,
  MediaAvailabilityFeed,
  MediaAvailabilityReceipt,
} from '../domain/repositories.js';
import type {
  ContentFactSource,
  MediaAvailabilityPort,
  MediaFactSource,
} from './ports/media_availability_port.js';

/** What one reconciliation of a Content did. */
export type MediaReconcileOutcome = 'suppressed' | 'unchanged' | 'unavailable' | 'no_publication';

export interface MediaAvailabilityConfig {
  readonly batchSize: number;
  readonly maxBatchesPerRun: number;
  /** Pointer compare-and-set attempts before a Content counts as contended. */
  readonly casAttempts: number;
  /** Content ids looked up for one asset (an asset binds to one Content). */
  readonly contentsPerAsset: number;
}

/** Local test-only bounds; not production values. */
export const mediaAvailabilityTestOnlyConfig: MediaAvailabilityConfig = Object.freeze({
  batchSize: 50,
  maxBatchesPerRun: 20,
  casAttempts: 3,
  contentsPerAsset: 10,
});

export interface FeedReport {
  readonly feed: MediaAvailabilityFeed;
  readonly processed: number;
  readonly suppressed: number;
  readonly deduped: number;
  /** Set when the run stopped; the checkpoint stays before this fact. */
  readonly stoppedAt: { readonly effectId: string; readonly code: string } | null;
  readonly checkpoint: FeedPosition | null;
  readonly synced: boolean;
}

export interface SweepReport {
  readonly checked: number;
  readonly suppressed: number;
  readonly unavailable: readonly string[];
}

export interface ContentMediaAvailabilityDeps {
  readonly repository: ContentRepository;
  readonly media: MediaAvailabilityPort;
  readonly mediaFacts: MediaFactSource;
  readonly contentFacts: ContentFactSource;
  readonly clock: ServerClock;
  readonly config?: MediaAvailabilityConfig;
}

const systemActor = 'system:media-availability';

function after(position: FeedPosition, checkpoint: FeedPosition | null): boolean {
  if (checkpoint === null) return true;
  if (position.occurredAtUtc !== checkpoint.occurredAtUtc)
    return position.occurredAtUtc > checkpoint.occurredAtUtc;
  return position.effectId > checkpoint.effectId;
}

/**
 * D2 reaction of Content to late Media restriction or deletion
 * (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §5). One core decides from Media's
 * current state — never from the kind or order of an event — whether the current
 * revision must stop showing some attached media; three runs share it: the
 * Media fact consumer, the Content fact verification and the sweep. Suppression
 * only grows here; only the publisher's activation clears it. Media is asked
 * outside any Content transaction, and the pointer is written with a
 * compare-and-set on the revision the decision was taken for.
 */
export class ContentMediaAvailability {
  readonly #config: MediaAvailabilityConfig;

  constructor(private readonly deps: ContentMediaAvailabilityDeps) {
    this.#config = deps.config ?? mediaAvailabilityTestOnlyConfig;
  }

  async reconcileContent(contentId: string): Promise<MediaReconcileOutcome> {
    for (let attempt = 0; attempt < this.#config.casAttempts; attempt += 1) {
      const snapshot = await this.deps.repository.transact(async (tx) => {
        const pointer = await tx.pointer(contentId);
        const currentId = pointer?.currentPublishedRevisionId ?? null;
        if (pointer === null || currentId === null) return null;
        const revision = await tx.publishedRevision(currentId);
        return revision === null ? null : { pointer, revision };
      });
      if (snapshot === null) return 'no_publication';
      const attachments = snapshot.revision.mediaAttachments;
      if (attachments.length === 0) return 'unchanged';
      let states: readonly AttachedMediaState[];
      try {
        states = await this.deps.media.availability(attachments.map((item) => item.assetId));
      } catch {
        return 'unavailable';
      }
      const needed = mediaSuppressionsFor(snapshot.pointer, attachments, states);
      const present = mediaSuppressionOf(snapshot.pointer);
      if (needed.every((item) => present.some((stored) => stored.assetId === item.assetId)))
        return 'unchanged';
      const nowUtc = parseUtcInstant(this.deps.clock.now().toISOString());
      try {
        return await this.deps.repository.transact(async (tx) => {
          const pointer = await tx.pointer(contentId);
          // The decision was taken for exactly this pointer revision.
          if (pointer === null || pointer.revision !== snapshot.pointer.revision)
            throw new ContentRepositoryConflict('pointer_revision');
          const next = suppressMedia(pointer, needed, nowUtc);
          if (next === pointer) return 'unchanged' as const;
          tx.putPointer(next, pointer.revision);
          tx.effects.append(
            contentEffect(
              snapshot.revision,
              next,
              'ContentMediaAvailabilityChanged',
              `${contentId}:media:${String(next.revision)}`,
              nowUtc,
            ),
          );
          tx.appendAudit({
            auditId: `${contentId}:media:${String(next.revision)}`,
            occurredAtUtc: nowUtc,
            actorUserId: systemActor,
            action: 'content.media.suppressed',
            subjectId: contentId,
            outcome: 'succeeded',
          });
          return 'suppressed' as const;
        });
      } catch (error) {
        if (error instanceof ContentRepositoryConflict) continue;
        throw error;
      }
    }
    return 'unavailable';
  }

  /** (a) Media facts: every Content attaching the asset is reconciled. */
  deliverMediaEffects(): Promise<FeedReport> {
    return this.#deliver('mediaEffects', async (after, limit) => {
      const facts = await this.deps.mediaFacts.effectsAfter(after, limit);
      return facts.map((fact) => ({
        effectId: fact.effectId,
        occurredAtUtc: fact.occurredAtUtc,
        hash: sha256Hex(canonicalJson(fact)),
        contentIds: async () =>
          this.deps.repository.transact((tx) =>
            tx.contentIdsAttachingMedia(fact.assetId, this.#config.contentsPerAsset),
          ),
      }));
    });
  }

  /**
   * (b) Content facts: after every publication, activation or media change the
   * Content is checked again. It closes the window between media evidence and the
   * commit (BCK-07 §38.11.2) and the same window of a publisher's confirmation.
   */
  deliverContentEffects(): Promise<FeedReport> {
    return this.#deliver('contentEffects', async (after, limit) => {
      const facts = await this.deps.contentFacts.effectsAfter(after, limit);
      return facts.map((fact) => ({
        effectId: fact.effectId,
        occurredAtUtc: fact.occurredAtUtc,
        hash: sha256Hex(canonicalJson(fact)),
        contentIds: () => Promise.resolve([fact.contentId]),
      }));
    });
  }

  /** R1: every current pointer, page by page; catches lost and skipped facts. */
  async sweep(): Promise<SweepReport> {
    let checked = 0;
    let suppressed = 0;
    const unavailable: string[] = [];
    let cursor: string | null = null;
    for (;;) {
      const page = await this.deps.repository.transact((tx) =>
        tx.pointersPage(cursor, this.#config.batchSize),
      );
      for (const pointer of page) {
        checked += 1;
        const outcome = await this.reconcileContent(pointer.contentId);
        if (outcome === 'suppressed') suppressed += 1;
        else if (outcome === 'unavailable') unavailable.push(pointer.contentId);
      }
      const last = page[page.length - 1];
      if (last === undefined || page.length < this.#config.batchSize) break;
      cursor = last.contentId;
    }
    return { checked, suppressed, unavailable };
  }

  /**
   * One consumer run: facts after its own checkpoint, in batches. A fact is
   * reconciled first and recorded afterwards (receipt and checkpoint in one
   * transaction): a lost worker repeats the reconciliation, which changes nothing
   * the second time. Media unavailable stops the run before the fact.
   */
  async #deliver(
    feed: MediaAvailabilityFeed,
    read: (
      after: FeedPosition | null,
      limit: number,
    ) => Promise<
      readonly {
        readonly effectId: string;
        readonly occurredAtUtc: string;
        readonly hash: string;
        readonly contentIds: () => Promise<readonly string[]>;
      }[]
    >,
  ): Promise<FeedReport> {
    let processed = 0;
    let suppressed = 0;
    let deduped = 0;
    let stoppedAt: FeedReport['stoppedAt'] = null;
    let synced = false;
    for (let batch = 0; batch < this.#config.maxBatchesPerRun && stoppedAt === null; batch += 1) {
      const status = await this.deps.repository.transact((tx) => tx.mediaAvailabilityStatus(feed));
      let facts: Awaited<ReturnType<typeof read>>;
      try {
        facts = await read(status?.checkpoint ?? null, this.#config.batchSize);
      } catch {
        stoppedAt = { effectId: '', code: 'source_unavailable' };
        break;
      }
      if (facts.length === 0) {
        synced = true;
        break;
      }
      for (const fact of facts) {
        const prior = await this.deps.repository.transact((tx) =>
          tx.mediaAvailabilityReceipt(feed, fact.effectId),
        );
        if (prior !== null) {
          if (prior.payloadHash !== fact.hash) {
            stoppedAt = { effectId: fact.effectId, code: 'receipt_conflict' };
            break;
          }
          await this.#record(feed, fact, null);
          deduped += 1;
          continue;
        }
        const outcomes: MediaAvailabilityReceipt['outcomes'][number][] = [];
        for (const contentId of await fact.contentIds())
          outcomes.push({ contentId, outcome: await this.reconcileContent(contentId) });
        if (outcomes.some((item) => item.outcome === 'unavailable')) {
          stoppedAt = { effectId: fact.effectId, code: 'media_unavailable' };
          break;
        }
        await this.#record(feed, fact, outcomes);
        processed += 1;
        suppressed += outcomes.filter((item) => item.outcome === 'suppressed').length;
      }
      if (facts.length < this.#config.batchSize && stoppedAt === null) synced = true;
      if (synced) break;
    }
    const checkpoint = await this.deps.repository.transact(
      async (tx) => (await tx.mediaAvailabilityStatus(feed))?.checkpoint ?? null,
    );
    return { feed, processed, suppressed, deduped, stoppedAt, checkpoint, synced };
  }

  async #record(
    feed: MediaAvailabilityFeed,
    fact: { readonly effectId: string; readonly occurredAtUtc: string; readonly hash: string },
    outcomes: MediaAvailabilityReceipt['outcomes'] | null,
  ): Promise<void> {
    const nowUtc = this.deps.clock.now().toISOString();
    await this.deps.repository.transact(async (tx) => {
      if (outcomes !== null && (await tx.mediaAvailabilityReceipt(feed, fact.effectId)) === null)
        tx.putMediaAvailabilityReceipt({
          feed,
          effectId: fact.effectId,
          payloadHash: fact.hash,
          outcomes,
          processedAtUtc: nowUtc,
        });
      const status = await tx.mediaAvailabilityStatus(feed);
      const position = { occurredAtUtc: fact.occurredAtUtc, effectId: fact.effectId };
      if (after(position, status?.checkpoint ?? null))
        tx.putMediaAvailabilityStatus({ feed, checkpoint: position, updatedAtUtc: nowUtc });
    });
  }
}
