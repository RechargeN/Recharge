import { randomUUID } from 'node:crypto';
import type { Firestore, QueryDocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import {
  contentTranslationFlagIds,
  operationsEmergencySwitchIds,
} from '../../shared/feature_flags.js';
import { safetyRestricted } from '../../shared/safety_instruction.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import { resolveContentType } from '../content/domain/content_type_registry.js';
import {
  assertContentEmulatorContext,
  contentCollections,
} from '../content/infrastructure/firestore_content_repository.js';
import { emergencySwitchState } from '../operations/emergency_switch.js';
import {
  allowlistedFields,
  cacheKeyOf,
  contentTranslationCollections as cols,
  contentTranslationStageOneLimits,
  contentTranslationTargetLocales,
  declaredSourceLocale,
  parseContentTranslationRequest,
  sourceHashOf,
  type ContentTranslationFailureCode,
  type ContentTranslationLimits,
  type ContentTranslationRequest,
  type TranslationFields,
} from './content_translation_contract.js';
import type { TranslationProvider } from './content_translation_provider.js';
import {
  acceptProviderOutput,
  characterCount,
  redactContacts,
} from './content_translation_text.js';

export type ContentTranslationResult =
  | {
      readonly schemaVersion: 1;
      readonly kind: 'rejected';
      readonly code: ContentTranslationFailureCode;
    }
  | {
      readonly schemaVersion: 1;
      readonly kind: 'offered';
      readonly contentId: string;
      readonly publishedRevisionId: string;
      readonly sourceLocale: string;
      readonly targetLocale: string;
    }
  | {
      readonly schemaVersion: 1;
      readonly kind: 'translated';
      readonly contentId: string;
      readonly publishedRevisionId: string;
      readonly sourceLocale: string;
      readonly targetLocale: string;
      readonly machineTranslated: true;
      readonly fields: TranslationFields;
    };

const rejected = (code: ContentTranslationFailureCode): ContentTranslationResult => ({
  schemaVersion: 1,
  kind: 'rejected',
  code,
});

interface Source {
  readonly fields: TranslationFields;
  readonly sourceLocale: string;
}

type Admission =
  | { readonly kind: 'done'; readonly result: ContentTranslationResult }
  | { readonly kind: 'wait'; readonly cacheKey: string }
  | {
      readonly kind: 'call';
      readonly cacheKey: string;
      readonly leaseToken: string;
      readonly source: Source;
      readonly reservedMinor: number;
    };

const entryFresh = (data: Record<string, unknown> | undefined, nowUtc: string): boolean =>
  data !== undefined && typeof data.expiresAtUtc === 'string' && data.expiresAtUtc > nowUtc;

/** Emulator-only. The only writer of its collections; it reads Content and never writes it. */
export class FirestoreContentTranslationService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
    private readonly provider: TranslationProvider,
    private readonly limits: ContentTranslationLimits = contentTranslationStageOneLimits,
    private readonly sleep: (ms: number) => Promise<void> = (ms) =>
      new Promise((resolve) => setTimeout(resolve, ms)),
  ) {
    assertContentEmulatorContext(db);
  }

  private async actor(tx: Transaction, hint: BookingAccessHint): Promise<string | null> {
    try {
      const decision = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      return decision.allowed ? decision.userId : null;
    } catch (error) {
      if (error instanceof TypeError) return null;
      throw error;
    }
  }

  /** Activation flag fails off; the L2 incident switch fails closed. */
  private async enabled(tx: Transaction): Promise<boolean> {
    const flag = await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(
      contentTranslationFlagIds.onDemand,
      tx,
    );
    if (!flag) return false;
    const state = await emergencySwitchState(
      this.db,
      operationsEmergencySwitchIds.contentTranslation,
      tx,
    );
    return state === 'open';
  }

  /** Invariant 4: the current public revision, on every read including a cache hit. */
  private async source(
    tx: Transaction,
    request: ContentTranslationRequest,
  ): Promise<Source | 'source_unavailable' | 'revision_changed'> {
    const pointer = (
      await tx.get(this.db.collection(contentCollections.pointers).doc(request.contentId))
    ).data();
    if (
      !pointer ||
      pointer.visibility !== 'visible' ||
      typeof pointer.currentPublishedRevisionId !== 'string'
    )
      return 'source_unavailable';
    if (pointer.currentPublishedRevisionId !== request.publishedRevisionId)
      return 'revision_changed';
    const revision = (
      await tx.get(
        this.db.collection(contentCollections.publishedRevisions).doc(request.publishedRevisionId),
      )
    ).data();
    const body = revision?.body as Record<string, unknown> | undefined;
    const typeId = typeof revision?.typeId === 'string' ? revision.typeId : '';
    const publisher = revision?.publisherRef as { id?: unknown } | undefined;
    if (
      !revision ||
      !body ||
      revision.contentId !== request.contentId ||
      revision.marketId !== 'LV' ||
      revision.bodyHash !== sha256Hex(canonicalJson(body)) ||
      resolveContentType(typeId)?.visibilityPolicy !== 'public_catalog' ||
      (body.visibility !== undefined && body.visibility !== 'public') ||
      typeof publisher?.id !== 'string'
    )
      return 'source_unavailable';
    if (
      await safetyRestricted(
        this.db,
        'content',
        publisher.id,
        this.clock.now(),
        request.contentId,
        tx,
      )
    )
      return 'source_unavailable';
    const fields = allowlistedFields(typeId, body);
    const sourceLocale = declaredSourceLocale(body);
    if (fields === null || sourceLocale === null) return 'source_unavailable';
    return { fields, sourceLocale };
  }

  private async gate(
    tx: Transaction,
    hint: BookingAccessHint,
    request: ContentTranslationRequest,
  ): Promise<
    | { readonly refusal: ContentTranslationFailureCode }
    | { readonly refusal: null; readonly actorId: string; readonly source: Source }
  > {
    const actorId = await this.actor(tx, hint);
    if (actorId === null) return { refusal: 'unauthenticated' };
    if (!(await this.enabled(tx))) return { refusal: 'translation_disabled' };
    if (!(contentTranslationTargetLocales as readonly string[]).includes(request.targetLocale))
      return { refusal: 'unsupported_locale' };
    const source = await this.source(tx, request);
    if (typeof source === 'string') return { refusal: source };
    if (source.sourceLocale === request.targetLocale) return { refusal: 'same_language' };
    return { refusal: null, actorId, source };
  }

  /** Read-only: tells Details whether to show the button. Spends nothing. */
  async offer(hint: BookingAccessHint, raw: unknown): Promise<ContentTranslationResult> {
    const request = parseContentTranslationRequest(raw);
    if (!request) return rejected('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const gate = await this.gate(tx, hint, request);
      if (gate.refusal !== null) return rejected(gate.refusal);
      return {
        schemaVersion: 1,
        kind: 'offered',
        contentId: request.contentId,
        publishedRevisionId: request.publishedRevisionId,
        sourceLocale: gate.source.sourceLocale,
        targetLocale: request.targetLocale,
      };
    });
  }

  async translate(hint: BookingAccessHint, raw: unknown): Promise<ContentTranslationResult> {
    const request = parseContentTranslationRequest(raw);
    if (!request) return rejected('request_invalid');
    for (let attempt = 0; attempt <= this.limits.waitAttempts; attempt++) {
      const admission = await this.admit(hint, request);
      if (admission.kind === 'done') return admission.result;
      if (admission.kind === 'call') return this.call(request, admission);
      await this.sleep(this.limits.waitMs);
    }
    return rejected('provider_unavailable');
  }

  private translated(
    request: ContentTranslationRequest,
    sourceLocale: string,
    fields: TranslationFields,
  ): ContentTranslationResult {
    return {
      schemaVersion: 1,
      kind: 'translated',
      contentId: request.contentId,
      publishedRevisionId: request.publishedRevisionId,
      sourceLocale,
      targetLocale: request.targetLocale,
      machineTranslated: true,
      fields,
    };
  }

  private costMinor(characters: number): number {
    return Math.ceil((characters * this.provider.rateMinorPerMillionChars) / 1_000_000);
  }

  private keyFor(request: ContentTranslationRequest, source: Source): string {
    return cacheKeyOf({
      contentId: request.contentId,
      publishedRevisionId: request.publishedRevisionId,
      sourceHash: sourceHashOf(source.fields),
      sourceLocale: source.sourceLocale,
      targetLocale: request.targetLocale,
      providerRef: this.provider.providerRef,
      engineRevision: this.provider.engineRevision,
    });
  }

  /**
   * One transaction: a cache hit spends nothing, a live lease waits uncharged, and
   * quota, budget and lease are taken together, before any provider call.
   */
  private admit(hint: BookingAccessHint, request: ContentTranslationRequest): Promise<Admission> {
    return this.db.runTransaction(async (tx): Promise<Admission> => {
      const done = (code: ContentTranslationFailureCode): Admission => ({
        kind: 'done',
        result: rejected(code),
      });
      const gate = await this.gate(tx, hint, request);
      if (gate.refusal !== null) return done(gate.refusal);
      const { actorId, source } = gate;
      const now = this.clock.now();
      const nowUtc = now.toISOString();
      const cacheKey = this.keyFor(request, source);
      const entry = (await tx.get(this.db.collection(cols.entries).doc(cacheKey))).data();
      if (entryFresh(entry, nowUtc))
        return {
          kind: 'done',
          result: this.translated(request, source.sourceLocale, entry!.fields as TranslationFields),
        };
      const leaseRef = this.db.collection(cols.leases).doc(cacheKey);
      const lease = (await tx.get(leaseRef)).data();
      if (lease && String(lease.leaseExpiresAtUtc) > nowUtc) return { kind: 'wait', cacheKey };

      const day = nowUtc.slice(0, 10);
      const accountRef = this.db.collection(cols.accountUsage).doc(actorId + ':' + day);
      const objectRef = this.db.collection(cols.objectUsage).doc(request.contentId + ':' + day);
      const accountCount = Number((await tx.get(accountRef)).data()?.count ?? 0);
      const objectCount = Number((await tx.get(objectRef)).data()?.count ?? 0);
      if (accountCount >= this.limits.accountPerDay || objectCount >= this.limits.objectPerDay)
        return done('quota_exceeded');

      const month = nowUtc.slice(0, 7);
      const budgetRef = this.db.collection(cols.budgets).doc(month);
      const budget = (await tx.get(budgetRef)).data();
      const expiredReservation = lease ? Number(lease.reservedMinor ?? 0) : 0;
      const reserved = Math.max(0, Number(budget?.reservedMinor ?? 0) - expiredReservation);
      const spent = Number(budget?.spentMinor ?? 0);
      const reservedMinor = this.costMinor(characterCount(source.fields));
      if (spent + reserved + reservedMinor > this.limits.monthlyCapMinor)
        return done('budget_exhausted');

      const expiresAtUtc = new Date(
        now.getTime() + this.limits.usageTtlDays * 86_400_000,
      ).toISOString();
      tx.set(accountRef, {
        schemaVersion: 1,
        accountId: actorId,
        day,
        count: accountCount + 1,
        expiresAtUtc,
      });
      tx.set(objectRef, {
        schemaVersion: 1,
        contentId: request.contentId,
        day,
        count: objectCount + 1,
        expiresAtUtc,
      });
      tx.set(budgetRef, {
        schemaVersion: 1,
        month,
        currency: this.provider.currency,
        capMinor: this.limits.monthlyCapMinor,
        reservedMinor: reserved + reservedMinor,
        spentMinor: spent,
      });
      const leaseToken = randomUUID();
      tx.set(leaseRef, {
        schemaVersion: 1,
        leaseToken,
        leaseExpiresAtUtc: new Date(now.getTime() + this.limits.leaseMs).toISOString(),
        month,
        reservedMinor,
      });
      return { kind: 'call', cacheKey, leaseToken, source, reservedMinor };
    });
  }

  private async call(
    request: ContentTranslationRequest,
    admission: Extract<Admission, { kind: 'call' }>,
  ): Promise<ContentTranslationResult> {
    const redacted = redactContacts(admission.source.fields);
    let fields: TranslationFields | null = null;
    try {
      fields = acceptProviderOutput(
        redacted,
        await this.provider.translate({
          sourceLocale: admission.source.sourceLocale,
          targetLocale: request.targetLocale,
          fields: redacted.fields,
        }),
      );
    } catch {
      fields = null;
    }
    return this.db.runTransaction(async (tx): Promise<ContentTranslationResult> => {
      const leaseRef = this.db.collection(cols.leases).doc(admission.cacheKey);
      const lease = (await tx.get(leaseRef)).data();
      // A lost worker's reservation and result belong to the lease that replaced it.
      if (lease?.leaseToken !== admission.leaseToken) return rejected('provider_unavailable');
      const now = this.clock.now();
      const nowUtc = now.toISOString();
      const month = String(lease.month);
      const budgetRef = this.db.collection(cols.budgets).doc(month);
      const budget = (await tx.get(budgetRef)).data();
      const source = fields === null ? null : await this.source(tx, request);
      const reserved = Math.max(0, Number(budget?.reservedMinor ?? 0) - admission.reservedMinor);
      const characters = characterCount(redacted.fields);
      const costMinor = fields === null ? 0 : this.costMinor(characters);
      tx.delete(leaseRef);
      tx.set(budgetRef, {
        schemaVersion: 1,
        month,
        currency: this.provider.currency,
        capMinor: this.limits.monthlyCapMinor,
        reservedMinor: reserved,
        spentMinor: Number(budget?.spentMinor ?? 0) + costMinor,
      });
      if (fields !== null)
        tx.set(this.db.collection(cols.costLedger).doc(admission.leaseToken), {
          schemaVersion: 1,
          month,
          providerRef: this.provider.providerRef,
          engineRevision: this.provider.engineRevision,
          sourceLocale: admission.source.sourceLocale,
          targetLocale: request.targetLocale,
          characters,
          amountMinor: costMinor,
          currency: this.provider.currency,
          recordedAtUtc: nowUtc,
        });
      if (fields === null) return rejected('provider_unavailable');
      // Hidden or replaced during the call: the provider was paid, nothing is kept or shown.
      if (typeof source === 'string' || source === null)
        return rejected(source ?? 'provider_unavailable');
      tx.set(this.db.collection(cols.entries).doc(admission.cacheKey), {
        schemaVersion: 1,
        contentId: request.contentId,
        publishedRevisionId: request.publishedRevisionId,
        sourceHash: sourceHashOf(admission.source.fields),
        sourceLocale: admission.source.sourceLocale,
        targetLocale: request.targetLocale,
        providerRef: this.provider.providerRef,
        engineRevision: this.provider.engineRevision,
        fields,
        createdAtUtc: nowUtc,
        expiresAtUtc: new Date(now.getTime() + this.limits.cacheTtlDays * 86_400_000).toISOString(),
      });
      return this.translated(request, admission.source.sourceLocale, fields);
    });
  }

  /** Withdrawal, restriction or deletion of the source removes its translations. */
  async purgeContent(contentId: string): Promise<number> {
    let purged = 0;
    for (;;) {
      const page = await this.db
        .collection(cols.entries)
        .where('contentId', '==', contentId)
        .limit(200)
        .get();
      if (page.empty) return purged;
      const batch = this.db.batch();
      for (const document of page.docs) batch.delete(document.ref);
      await batch.commit();
      purged += page.size;
    }
  }

  /**
   * Idempotent rescan: removes translations past their TTL or whose source is no
   * longer public, and expired usage counters, including after a missed trigger.
   */
  async sweep(pageSize = 200): Promise<{ readonly removed: number }> {
    const nowUtc = this.clock.now().toISOString();
    let removed = 0;
    for (const name of [cols.accountUsage, cols.objectUsage]) {
      const expired = await this.db
        .collection(name)
        .where('expiresAtUtc', '<=', nowUtc)
        .limit(pageSize)
        .get();
      for (const document of expired.docs) await document.ref.delete();
      removed += expired.size;
    }
    let after: QueryDocumentSnapshot | undefined;
    for (;;) {
      const base = this.db.collection(cols.entries).orderBy('__name__').limit(pageSize);
      const page = await (after === undefined ? base : base.startAfter(after)).get();
      if (page.empty) return { removed };
      for (const document of page.docs) {
        const data = document.data();
        const expired = !entryFresh(data, nowUtc);
        if (expired || !(await this.sourceStillPublic(String(data.contentId)))) {
          await document.ref.delete();
          removed += 1;
        }
      }
      after = page.docs.at(-1);
    }
  }

  private async sourceStillPublic(contentId: string): Promise<boolean> {
    const pointer = (
      await this.db.collection(contentCollections.pointers).doc(contentId).get()
    ).data();
    if (pointer?.visibility !== 'visible') return false;
    const revision = (
      await this.db
        .collection(contentCollections.publishedRevisions)
        .doc(String(pointer.currentPublishedRevisionId))
        .get()
    ).data();
    const publisher = revision?.publisherRef as { id?: unknown } | undefined;
    return (
      typeof publisher?.id === 'string' &&
      !(await safetyRestricted(this.db, 'content', publisher.id, this.clock.now(), contentId))
    );
  }
}
