import type { ContentBody, ContentEffectV1 } from '../../../contracts/content_v1.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import {
  bookingOutboxId,
  internalRegistrationTerms,
  planBookingHandoff,
  type EventBookingFactV1,
  type HandoffContentState,
} from '../domain/event_internal_registration.js';
import { canonicalJson, sha256Hex } from '../domain/published_revision.js';
import type { EffectCursor } from '../domain/repositories.js';

/** Test-only bounds of the local handoff (not product defaults). */
export const eventBookingHandoffConfig = Object.freeze({
  batchSize: 100,
  maxBatchesPerRun: 50,
  historyPageSize: 200,
  reconcileBatchSize: 200,
});

export interface HandoffPosition {
  readonly occurredAtUtc: string;
  readonly effectId: string;
}

export interface HandoffStatusRecord {
  readonly schemaVersion: 1;
  /** The last effect of the global feed every earlier effect is handled for. */
  readonly checkpoint: HandoffPosition | null;
  /** Set while a run stopped or failed; cleared by a complete run. */
  readonly pendingSince: string | null;
  readonly reason: string | null;
  readonly updatedAtUtc: string;
}

export interface HandoffReceiptRecord {
  readonly schemaVersion: 1;
  readonly effectId: string;
  readonly payloadHash: string;
  readonly contentId: string;
  readonly pointerRevision: number;
  readonly outcome: 'applied' | 'ignored';
  readonly outboxIds: readonly string[];
  readonly findings: readonly string[];
  readonly processedAtUtc: string;
}

export interface HandoffTransaction {
  status(): Promise<HandoffStatusRecord | null>;
  putStatus(record: HandoffStatusRecord): void;
  receipt(effectId: string): Promise<HandoffReceiptRecord | null>;
  /** Create-only. */
  putReceipt(record: HandoffReceiptRecord): void;
  state(contentId: string): Promise<HandoffContentState | null>;
  putState(record: HandoffContentState): void;
  outboxExists(outboxId: string): Promise<boolean>;
  /** Create-only; an existing id is left as it is. */
  createOutbox(outboxId: string, fact: EventBookingFactV1, createdAtUtc: string): void;
}

export interface HandoffRepository {
  transact<T>(operation: (transaction: HandoffTransaction) => Promise<T>): Promise<T>;
}

/** Read-only view of what Content committed. */
export interface HandoffSource {
  effectsAfter(after: HandoffPosition | null, limit: number): Promise<readonly ContentEffectV1[]>;
  effectsForContent(
    contentId: string,
    after: EffectCursor | null,
    limit: number,
  ): Promise<readonly ContentEffectV1[]>;
  publishedRevision(
    publishedRevisionId: string,
  ): Promise<{ readonly typeId: string; readonly body: ContentBody } | null>;
  pointersPage(
    afterContentId: string | null,
    limit: number,
  ): Promise<
    readonly {
      readonly contentId: string;
      readonly revision: number;
      readonly currentPublishedRevisionId: string | null;
    }[]
  >;
}

/** Read-only view of Booking, for reconciliation only. */
export interface BookingProjectionReader {
  projection(
    occurrenceId: string,
  ): Promise<{ readonly publicationRevision: number; readonly lifecycle: string } | null>;
  deadLetteredOutboxIds(prefix: string): Promise<readonly string[]>;
}

export interface HandoffReport {
  readonly processed: number;
  readonly applied: number;
  readonly deduped: number;
  readonly ignored: number;
  readonly facts: number;
  /** Set when the run stopped; the checkpoint stays before this effect. */
  readonly stoppedAt: { readonly effectId: string; readonly code: string } | null;
  readonly synced: boolean;
}

export interface HandoffFinding {
  readonly code:
    | 'handoff_gap'
    | 'handoff_pending'
    | 'outbox_missing'
    | 'delivery_dead_letter'
    | 'projection_behind'
    | 'projection_ahead';
  readonly contentId?: string;
  readonly occurrenceId?: string;
  readonly detail?: string;
}

export interface HandoffReconcileReport {
  readonly complete: boolean;
  readonly findings: readonly HandoffFinding[];
  /** Not blocking: a re-added occurrence id that was cancelled stays cancelled. */
  readonly notices: readonly { readonly contentId: string; readonly occurrenceId: string }[];
}

type Step =
  | { readonly kind: 'applied'; readonly facts: number }
  | { readonly kind: 'deduped' | 'ignored' }
  | { readonly kind: 'stopped'; readonly code: string };

function after(position: HandoffPosition, checkpoint: HandoffPosition | null): boolean {
  if (checkpoint === null) return true;
  if (position.occurredAtUtc !== checkpoint.occurredAtUtc)
    return position.occurredAtUtc > checkpoint.occurredAtUtc;
  return position.effectId > checkpoint.effectId;
}

/**
 * Content-owned Event → Booking handoff (E2.0, BCK-07 §35). Event is the only
 * writer of `eventBookingOutbox`; Booking keeps its own delivery records. The
 * handoff has its own checkpoint, receipts and per-object state, so it never
 * shares a "processed" mark with the Catalog.
 *
 * Objects are processed strictly in `pointerRevision` order: a gap is filled
 * from the history Content stored, never assumed, and the global checkpoint
 * only moves past an effect that is handled.
 */
export class EventBookingHandoff {
  constructor(
    private readonly deps: {
      readonly repository: HandoffRepository;
      readonly source: HandoffSource;
      readonly booking: BookingProjectionReader;
      readonly clock: ServerClock;
    },
  ) {}

  async deliver(): Promise<HandoffReport> {
    const nowUtc = this.deps.clock.now().toISOString();
    const counts = { processed: 0, applied: 0, deduped: 0, ignored: 0, facts: 0 };
    let stoppedAt: HandoffReport['stoppedAt'] = null;
    let synced = false;
    try {
      for (
        let batch = 0;
        batch < eventBookingHandoffConfig.maxBatchesPerRun && stoppedAt === null && !synced;
        batch += 1
      ) {
        const status = await this.deps.repository.transact((tx) => tx.status());
        const effects = await this.deps.source.effectsAfter(
          status?.checkpoint ?? null,
          eventBookingHandoffConfig.batchSize,
        );
        if (effects.length === 0) {
          synced = true;
          break;
        }
        for (const effect of effects) {
          const step = await this.#process(effect, nowUtc);
          if (step.kind === 'stopped') {
            stoppedAt = { effectId: effect.effectId, code: step.code };
            break;
          }
          counts.processed += 1;
          if (step.kind === 'applied') {
            counts.applied += 1;
            counts.facts += step.facts;
          } else counts[step.kind] += 1;
        }
      }
    } catch (error) {
      await this.#markPending(nowUtc, error instanceof Error ? error.name : 'UnknownError');
      throw error;
    }
    if (stoppedAt === null) await this.#clearPending(nowUtc);
    else await this.#markPending(nowUtc, stoppedAt.code);
    return { ...counts, stoppedAt, synced };
  }

  async #process(effect: ContentEffectV1, nowUtc: string): Promise<Step> {
    if (effect.typeId !== 'event') return this.#ignore(effect, nowUtc);
    const state = await this.deps.repository.transact((tx) => tx.state(effect.contentId));
    const last = state?.lastPointerRevision ?? 0;
    if (effect.pointerRevision <= last) return this.#dedupe(effect, nowUtc);
    if (effect.pointerRevision > last + 1) {
      const missing = await this.#history(effect.contentId, last, effect.pointerRevision);
      if (missing === null) return { kind: 'stopped', code: 'source_effect_missing' };
      for (const earlier of missing) {
        const step = await this.#apply(earlier, false, nowUtc);
        if (step.kind === 'stopped') return step;
      }
    }
    return this.#apply(effect, true, nowUtc);
  }

  /**
   * The stored effects after [afterRevision] (and before [beforeRevision] when
   * given), contiguous in `pointerRevision`; null when Content lost one.
   */
  async #history(
    contentId: string,
    afterRevision: number,
    beforeRevision: number | null,
  ): Promise<ContentEffectV1[] | null> {
    const before = beforeRevision ?? Number.MAX_SAFE_INTEGER;
    const found: ContentEffectV1[] = [];
    let cursor: EffectCursor | null = null;
    for (;;) {
      const page = await this.deps.source.effectsForContent(
        contentId,
        cursor,
        eventBookingHandoffConfig.historyPageSize,
      );
      for (const effect of page)
        if (effect.pointerRevision > afterRevision && effect.pointerRevision < before)
          found.push(effect);
      const last = page[page.length - 1];
      if (
        last === undefined ||
        page.length < eventBookingHandoffConfig.historyPageSize ||
        last.pointerRevision >= before
      )
        break;
      cursor = { pointerRevision: last.pointerRevision, effectId: last.effectId };
    }
    found.sort((left, right) => left.pointerRevision - right.pointerRevision);
    for (let index = 0; index < found.length; index += 1)
      if (found[index]?.pointerRevision !== afterRevision + 1 + index) return null;
    if (beforeRevision !== null && found.length !== beforeRevision - afterRevision - 1) return null;
    return found;
  }

  #advance(
    tx: HandoffTransaction,
    status: HandoffStatusRecord | null,
    effect: ContentEffectV1,
    nowUtc: string,
  ): void {
    const position = { occurredAtUtc: effect.occurredAtUtc, effectId: effect.effectId };
    if (!after(position, status?.checkpoint ?? null)) return;
    tx.putStatus({
      schemaVersion: 1,
      checkpoint: position,
      pendingSince: status?.pendingSince ?? null,
      reason: status?.reason ?? null,
      updatedAtUtc: nowUtc,
    });
  }

  #ignore(effect: ContentEffectV1, nowUtc: string): Promise<Step> {
    return this.deps.repository.transact(async (tx) => {
      const status = await tx.status();
      const receipt = await tx.receipt(effect.effectId);
      if (receipt === null)
        tx.putReceipt({
          schemaVersion: 1,
          effectId: effect.effectId,
          payloadHash: sha256Hex(canonicalJson(effect)),
          contentId: effect.contentId,
          pointerRevision: effect.pointerRevision,
          outcome: 'ignored',
          outboxIds: [],
          findings: [],
          processedAtUtc: nowUtc,
        });
      this.#advance(tx, status, effect, nowUtc);
      return { kind: 'ignored' } as const;
    });
  }

  #dedupe(effect: ContentEffectV1, nowUtc: string): Promise<Step> {
    return this.deps.repository.transact(async (tx) => {
      const status = await tx.status();
      this.#advance(tx, status, effect, nowUtc);
      return { kind: 'deduped' } as const;
    });
  }

  async #apply(effect: ContentEffectV1, advance: boolean, nowUtc: string): Promise<Step> {
    // Immutable source read outside the transaction; a missing revision stops.
    const revision = await this.deps.source.publishedRevision(effect.publishedRevisionId);
    if (revision === null) return { kind: 'stopped', code: 'source_revision_missing' };
    const payloadHash = sha256Hex(canonicalJson(effect));
    return this.deps.repository.transact(async (tx): Promise<Step> => {
      const status = await tx.status();
      const receipt = await tx.receipt(effect.effectId);
      const state = await tx.state(effect.contentId);
      if (receipt !== null) {
        if (receipt.payloadHash !== payloadHash)
          return { kind: 'stopped', code: 'receipt_conflict' };
        if (advance) this.#advance(tx, status, effect, nowUtc);
        return { kind: 'deduped' };
      }
      const last = state?.lastPointerRevision ?? 0;
      if (effect.pointerRevision <= last) {
        if (advance) this.#advance(tx, status, effect, nowUtc);
        return { kind: 'deduped' };
      }
      if (effect.pointerRevision !== last + 1) return { kind: 'stopped', code: 'pointer_gap' };
      const plan = planBookingHandoff(
        state,
        {
          effectId: effect.effectId,
          contentId: effect.contentId,
          pointerRevision: effect.pointerRevision,
          visibility: effect.visibility,
          marketId: effect.marketId,
          publisherRef: effect.publisherRef,
          occurredAtUtc: effect.occurredAtUtc,
          mediaOnly: effect.kind === 'ContentMediaAvailabilityChanged',
        },
        revision.body,
      );
      const outboxIds: string[] = [];
      for (const fact of plan.facts) {
        const outboxId = bookingOutboxId(effect.effectId, fact);
        outboxIds.push(outboxId);
        tx.createOutbox(outboxId, fact, nowUtc);
      }
      tx.putState(plan.next);
      tx.putReceipt({
        schemaVersion: 1,
        effectId: effect.effectId,
        payloadHash,
        contentId: effect.contentId,
        pointerRevision: effect.pointerRevision,
        outcome: 'applied',
        outboxIds,
        findings: [...plan.findings],
        processedAtUtc: nowUtc,
      });
      if (advance) this.#advance(tx, status, effect, nowUtc);
      return { kind: 'applied', facts: plan.facts.length };
    });
  }

  async #markPending(nowUtc: string, reason: string): Promise<void> {
    await this.deps.repository.transact(async (tx) => {
      const status = await tx.status();
      tx.putStatus({
        schemaVersion: 1,
        checkpoint: status?.checkpoint ?? null,
        pendingSince: status?.pendingSince ?? nowUtc,
        reason,
        updatedAtUtc: nowUtc,
      });
    });
  }

  async #clearPending(nowUtc: string): Promise<void> {
    await this.deps.repository.transact(async (tx) => {
      const status = await tx.status();
      if (status === null || status.pendingSince === null) return;
      tx.putStatus({ ...status, pendingSince: null, reason: null, updatedAtUtc: nowUtc });
    });
  }

  /**
   * §6: Content pointers and stored history against the handoff state and the
   * Booking projections (read-only). It sees a lag even when no new effect
   * will ever arrive.
   */
  async reconcile(): Promise<HandoffReconcileReport> {
    const findings: HandoffFinding[] = [];
    const notices: { contentId: string; occurrenceId: string }[] = [];
    const status = await this.deps.repository.transact((tx) => tx.status());
    if (status?.pendingSince !== null && status?.pendingSince !== undefined)
      findings.push({ code: 'handoff_pending', detail: status.reason ?? 'unknown' });
    let afterContentId: string | null = null;
    for (;;) {
      const pointers = await this.deps.source.pointersPage(
        afterContentId,
        eventBookingHandoffConfig.reconcileBatchSize,
      );
      for (const pointer of pointers) {
        const current =
          pointer.currentPublishedRevisionId === null
            ? null
            : await this.deps.source.publishedRevision(pointer.currentPublishedRevisionId);
        if (current?.typeId !== 'event') continue;
        const state = await this.deps.repository.transact((tx) => tx.state(pointer.contentId));
        const last = state?.lastPointerRevision ?? 0;
        if (pointer.revision > last)
          findings.push({
            code: 'handoff_gap',
            contentId: pointer.contentId,
            detail: `handoff ${last} < content ${pointer.revision}`,
          });
        if (state === null) continue;
        const terms = internalRegistrationTerms(current.body);
        for (const occurrence of Object.values(state.occurrences)) {
          if (
            occurrence.terminal === 'cancelled' &&
            terms?.occurrences.some((slot) => slot.id === occurrence.occurrenceId) === true
          )
            notices.push({ contentId: pointer.contentId, occurrenceId: occurrence.occurrenceId });
          if (occurrence.lastOutboxId === null) continue;
          const outboxId = occurrence.lastOutboxId;
          const exists = await this.deps.repository.transact((tx) => tx.outboxExists(outboxId));
          if (!exists) {
            findings.push({
              code: 'outbox_missing',
              contentId: pointer.contentId,
              occurrenceId: occurrence.occurrenceId,
              detail: outboxId,
            });
            continue;
          }
          const projection = await this.deps.booking.projection(occurrence.occurrenceId);
          const delivered = projection?.publicationRevision ?? 0;
          if (delivered < occurrence.lastPublicationRevision)
            findings.push({
              code: 'projection_behind',
              contentId: pointer.contentId,
              occurrenceId: occurrence.occurrenceId,
              detail: `booking ${delivered} < handoff ${occurrence.lastPublicationRevision}`,
            });
          else if (delivered > occurrence.lastPublicationRevision)
            findings.push({
              code: 'projection_ahead',
              contentId: pointer.contentId,
              occurrenceId: occurrence.occurrenceId,
              detail: `booking ${delivered} > handoff ${occurrence.lastPublicationRevision}`,
            });
        }
      }
      const last = pointers[pointers.length - 1];
      if (last === undefined || pointers.length < eventBookingHandoffConfig.reconcileBatchSize)
        break;
      afterContentId = last.contentId;
    }
    for (const outboxId of await this.deps.booking.deadLetteredOutboxIds('ebh_'))
      findings.push({ code: 'delivery_dead_letter', detail: outboxId });
    return { complete: findings.length === 0, findings, notices };
  }

  /**
   * Recovery of `outbox_missing`: replays the object's stored history in
   * memory and creates only the outbox records that are absent. Ids are
   * deterministic and Booking deduplicates, so nothing is ever invented.
   */
  async repairContent(contentId: string): Promise<{ readonly created: number }> {
    const nowUtc = this.deps.clock.now().toISOString();
    const history = await this.#history(contentId, 0, null);
    if (history === null) throw new Error('source_effect_missing');
    let state: HandoffContentState | null = null;
    let created = 0;
    for (const effect of history) {
      const revision = await this.deps.source.publishedRevision(effect.publishedRevisionId);
      if (revision === null) throw new Error('source_revision_missing');
      const plan = planBookingHandoff(
        state,
        {
          effectId: effect.effectId,
          contentId,
          pointerRevision: effect.pointerRevision,
          visibility: effect.visibility,
          marketId: effect.marketId,
          publisherRef: effect.publisherRef,
          occurredAtUtc: effect.occurredAtUtc,
          mediaOnly: effect.kind === 'ContentMediaAvailabilityChanged',
        },
        revision.body,
      );
      state = plan.next;
      for (const fact of plan.facts) {
        const outboxId = bookingOutboxId(effect.effectId, fact);
        const made = await this.deps.repository.transact(async (tx) => {
          if (await tx.outboxExists(outboxId)) return false;
          tx.createOutbox(outboxId, fact, nowUtc);
          return true;
        });
        if (made) created += 1;
      }
    }
    return { created };
  }
}
