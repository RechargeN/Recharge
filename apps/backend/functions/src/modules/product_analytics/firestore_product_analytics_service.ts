import { createHash, randomUUID } from 'node:crypto';
import type { DocumentReference, Firestore, Transaction } from 'firebase-admin/firestore';

import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import { productAnalyticsFlagIds } from '../../shared/feature_flags.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { assertCurrentSession } from '../identity_publisher/domain/session.js';
import { identityAuthorityCollections as identity } from '../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import {
  eventDayUtc,
  parseProductAnalyticsBatch,
  productAnalyticsCollections as cols,
  productAnalyticsLimits,
  productAnalyticsPurposeId,
  productAnalyticsRegistryRevision,
  validDayUtc,
  type ProductAnalyticsEvent,
} from './product_analytics_contract.js';
import {
  absentProductAnalyticsConsent,
  acceptedProductAnalyticsPolicy,
  unresolvedProductAnalyticsPolicy,
  type ProductAnalyticsCollectionPolicy,
  type ProductAnalyticsConsentPort,
  type ProductAnalyticsPolicyPort,
} from './product_analytics_policy.js';

export type ProductAnalyticsDisposition =
  'accepted' | 'duplicate' | 'rejected_schema' | 'rejected_policy' | 'rejected_late' | 'conflict';

export type ProductAnalyticsIngestResult =
  | {
      readonly kind: 'processed';
      readonly results: readonly {
        readonly eventId: string | null;
        readonly disposition: ProductAnalyticsDisposition;
      }[];
    }
  | {
      readonly kind: 'refused';
      readonly code:
        | 'batch_invalid'
        | 'policy_unavailable'
        | 'collection_disabled'
        | 'unauthenticated'
        | 'consent_absent';
    };

export type ProductAnalyticsBuildResult =
  | {
      readonly kind: 'built';
      readonly dayUtc: string;
      readonly sourceEvents: number;
      readonly fingerprint: string;
    }
  | {
      readonly kind: 'refused';
      readonly code:
        | 'request_invalid'
        | 'policy_unavailable'
        | 'aggregation_disabled'
        | 'window_expired'
        | 'source_too_large';
    };

export interface ProductAnalyticsAggregateRow {
  readonly eventName: string;
  readonly eventVersion: number;
  readonly fields: Readonly<Record<string, string>>;
  readonly count: number;
}

/** A verified staff Session subject; a trusted internal input, never client claims. */
export interface ProductAnalyticsReader {
  readonly userId: string;
  readonly sessionId: string;
}

export const productAnalyticsAccessActions = Object.freeze({
  aggregateRead: 'aggregate.read',
  rawRead: 'raw.read',
  export: 'export',
});
export type ProductAnalyticsAccessAction =
  (typeof productAnalyticsAccessActions)[keyof typeof productAnalyticsAccessActions];

export const productAnalyticsAuthoritySource = 'test-only-emulator-stand-bootstrap';
export const productAnalyticsAccessPolicy = 'test-only-l3-access-v1';

export type ProductAnalyticsReadResult =
  | {
      readonly kind: 'succeeded';
      readonly days: readonly {
        readonly dayUtc: string;
        readonly fingerprint: string;
        readonly rows: readonly ProductAnalyticsAggregateRow[];
      }[];
    }
  | {
      readonly kind: 'refused';
      readonly code: 'request_invalid' | 'access_denied' | 'policy_unavailable';
    };

const hourMs = 60 * 60 * 1000;
const sweepPageSize = 200;
/** A day with more raw events than this is refused, never published partially. */
const aggregateSourceMaxEvents = 5000;
const idPattern = /^[A-Za-z0-9_-]{1,128}$/u;

const dayStartMs = (dayUtc: string) => Date.parse(`${dayUtc}T00:00:00.000Z`);
const isoAfter = (dayUtc: string, hours: number) =>
  new Date(dayStartMs(dayUtc) + hours * hourMs).toISOString();

function sameEvent(stored: Record<string, unknown>, event: ProductAnalyticsEvent) {
  return (
    stored.eventName === event.eventName &&
    stored.eventVersion === event.eventVersion &&
    stored.occurredDayUtc === eventDayUtc(event.occurredAtUtc) &&
    stored.policyRevision === event.policyRevision &&
    JSON.stringify(stored.fields) === JSON.stringify(event.fields)
  );
}

function rowKey(row: Pick<ProductAnalyticsAggregateRow, 'eventName' | 'eventVersion' | 'fields'>) {
  const fields = Object.keys(row.fields)
    .sort()
    .map((name) => `${name}=${row.fields[name]!}`)
    .join('&');
  return `${row.eventName}|${String(row.eventVersion)}|${fields}`;
}

/**
 * L3 product analytics boundary (amendment §4–§9). Local Emulator only; no
 * callable, trigger, scheduler or network destination. It writes only the
 * `productAnalytics*` collections, never a log line with event content, and
 * never another domain's records. Every step fails closed: no policy, no flag,
 * no current Session or no consent means nothing is stored.
 */
export class FirestoreProductAnalyticsService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
    private readonly policy: ProductAnalyticsPolicyPort = unresolvedProductAnalyticsPolicy,
    private readonly consent: ProductAnalyticsConsentPort = absentProductAnalyticsConsent,
  ) {
    assertContentEmulatorContext(db);
  }

  async ingest(hint: BookingAccessHint, raw: unknown): Promise<ProductAnalyticsIngestResult> {
    const entries = parseProductAnalyticsBatch(raw);
    if (entries === null) return { kind: 'refused', code: 'batch_invalid' };
    const now = this.clock.now();
    const policy = this.#policy(now);
    if (policy === null) return { kind: 'refused', code: 'policy_unavailable' };
    return this.db.runTransaction(async (tx) => {
      if (!(await this.#flag(tx, productAnalyticsFlagIds.collection)))
        return { kind: 'refused', code: 'collection_disabled' } as const;
      const userId = await this.#sender(tx, hint, now);
      if (userId === null) return { kind: 'refused', code: 'unauthenticated' } as const;
      // The sender is used for this check only and is never stored.
      if (
        policy.consentRequired &&
        (await this.consent.state(userId, productAnalyticsPurposeId, policy.policyRevision)) !==
          'granted'
      )
        return { kind: 'refused', code: 'consent_absent' } as const;
      const candidates = entries.flatMap((entry) =>
        entry.valid && this.#admissible(entry.event, policy, now) === null ? [entry.event] : [],
      );
      const ids = [...new Set(candidates.map((event) => event.eventId))];
      const refs = ids.map((id) => this.db.collection(cols.events).doc(id));
      const stored = new Map<string, Record<string, unknown> | undefined>();
      if (refs.length > 0)
        for (const snapshot of await tx.getAll(...refs)) stored.set(snapshot.id, snapshot.data());
      const results = entries.map((entry) => {
        if (!entry.valid)
          return { eventId: entry.eventId, disposition: 'rejected_schema' as const };
        const { event } = entry;
        const refusal = this.#admissible(event, policy, now);
        if (refusal !== null) return { eventId: event.eventId, disposition: refusal };
        const prior = stored.get(event.eventId);
        if (prior !== undefined)
          return {
            eventId: event.eventId,
            disposition: sameEvent(prior, event) ? ('duplicate' as const) : ('conflict' as const),
          };
        const record = {
          schemaVersion: 1,
          registryRevision: productAnalyticsRegistryRevision,
          eventName: event.eventName,
          eventVersion: event.eventVersion,
          occurredDayUtc: eventDayUtc(event.occurredAtUtc),
          policyRevision: event.policyRevision,
          fields: { ...event.fields },
          environmentId: 'local',
          marketId: 'LV',
          expiresAtUtc: isoAfter(eventDayUtc(event.occurredAtUtc), policy.rawRetentionHours),
        };
        tx.create(this.db.collection(cols.events).doc(event.eventId), record);
        // A repeat inside the same batch compares against what this batch stores.
        stored.set(event.eventId, record);
        return { eventId: event.eventId, disposition: 'accepted' as const };
      });
      return { kind: 'processed', results } as const;
    });
  }

  /**
   * Deterministic full rebuild of one day from the raw zone, written as one
   * document. A day whose raw events have started to expire is refused, so an
   * expired or deleted event is never counted again and no partial day is kept.
   */
  async rebuildDailyAggregate(dayUtc: string): Promise<ProductAnalyticsBuildResult> {
    if (!validDayUtc(dayUtc)) return { kind: 'refused', code: 'request_invalid' };
    const now = this.clock.now();
    const policy = this.#policy(now);
    if (policy === null) return { kind: 'refused', code: 'policy_unavailable' };
    if (
      dayStartMs(dayUtc) + policy.rawRetentionHours * hourMs <= now.getTime() ||
      dayStartMs(dayUtc) + policy.aggregateRetentionHours * hourMs <= now.getTime()
    )
      return { kind: 'refused', code: 'window_expired' };
    return this.db.runTransaction(async (tx) => {
      if (!(await this.#flag(tx, productAnalyticsFlagIds.aggregation)))
        return { kind: 'refused', code: 'aggregation_disabled' } as const;
      const source = await tx.get(
        this.db
          .collection(cols.events)
          .where('occurredDayUtc', '==', dayUtc)
          .limit(aggregateSourceMaxEvents + 1),
      );
      if (source.size > aggregateSourceMaxEvents)
        return { kind: 'refused', code: 'source_too_large' } as const;
      const counts = new Map<string, ProductAnalyticsAggregateRow>();
      for (const doc of source.docs) {
        const data = doc.data();
        const row = {
          eventName: String(data.eventName),
          eventVersion: Number(data.eventVersion),
          fields: data.fields as Record<string, string>,
        };
        const key = rowKey(row);
        const prior = counts.get(key);
        counts.set(key, { ...row, count: (prior?.count ?? 0) + 1 });
      }
      const rows = [...counts.entries()]
        .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0))
        .map(([, row]) => row);
      const fingerprint = createHash('sha256')
        .update(JSON.stringify({ dayUtc, registry: productAnalyticsRegistryRevision, rows }))
        .digest('hex');
      tx.set(this.db.collection(cols.dailyAggregates).doc(dayUtc), {
        schemaVersion: 1,
        registryRevision: productAnalyticsRegistryRevision,
        dayUtc,
        rows,
        sourceEvents: source.size,
        fingerprint,
        expiresAtUtc: isoAfter(dayUtc, policy.aggregateRetentionHours),
      });
      return { kind: 'built', dayUtc, sourceEvents: source.size, fingerprint } as const;
    });
  }

  /**
   * Retention sweep over the raw zone and the aggregates by the expiry stamped
   * at write time. It needs no policy and no flag, so disabling collection
   * never stops deletion.
   */
  async expire(): Promise<{ readonly events: number; readonly aggregates: number }> {
    const nowUtc = this.clock.now().toISOString();
    const sweep = async (collection: string) => {
      let deleted = 0;
      for (;;) {
        const page = await this.db
          .collection(collection)
          .where('expiresAtUtc', '<=', nowUtc)
          .limit(sweepPageSize)
          .get();
        if (page.empty) return deleted;
        const batch = this.db.batch();
        for (const doc of page.docs) batch.delete(doc.ref);
        await batch.commit();
        deleted += page.size;
      }
    };
    return { events: await sweep(cols.events), aggregates: await sweep(cols.dailyAggregates) };
  }

  /**
   * Aggregate read for a staff Session with the `aggregate.read` capability of
   * the test-only registry. The decision and its audit record commit together;
   * the answer holds aggregate rows and fingerprints only.
   */
  async readDailyAggregates(
    reader: ProductAnalyticsReader,
    fromDayUtc: string,
    toDayUtc: string,
  ): Promise<ProductAnalyticsReadResult> {
    if (!validDayUtc(fromDayUtc) || !validDayUtc(toDayUtc))
      return { kind: 'refused', code: 'request_invalid' };
    const span = (dayStartMs(toDayUtc) - dayStartMs(fromDayUtc)) / (24 * hourMs) + 1;
    if (span < 1 || span > productAnalyticsLimits.aggregateReadMaxDays)
      return { kind: 'refused', code: 'request_invalid' };
    const days = Array.from({ length: span }, (_, index) =>
      new Date(dayStartMs(fromDayUtc) + index * 24 * hourMs).toISOString().slice(0, 10),
    );
    const nowUtc = this.clock.now().toISOString();
    return this.db.runTransaction(async (tx) => {
      const allowed = await this.#allowed(
        tx,
        reader,
        productAnalyticsAccessActions.aggregateRead,
        nowUtc,
      );
      const snapshots = allowed
        ? await tx.getAll(...days.map((day) => this.db.collection(cols.dailyAggregates).doc(day)))
        : [];
      this.#audit(tx, reader, productAnalyticsAccessActions.aggregateRead, {
        outcome: allowed ? 'allow' : 'deny',
        reason: allowed ? 'granted' : 'access_denied',
        fromDayUtc,
        toDayUtc,
        nowUtc,
      });
      if (!allowed) return { kind: 'refused', code: 'access_denied' } as const;
      return {
        kind: 'succeeded',
        days: snapshots.flatMap((snapshot) => {
          const data = snapshot.data();
          if (data === undefined || data.expiresAtUtc <= nowUtc) return [];
          return [
            {
              dayUtc: String(data.dayUtc),
              fingerprint: String(data.fingerprint),
              rows: (data.rows as ProductAnalyticsAggregateRow[]).map((row) => ({
                eventName: row.eventName,
                eventVersion: row.eventVersion,
                fields: { ...row.fields },
                count: row.count,
              })),
            },
          ];
        }),
      } as const;
    });
  }

  /**
   * Raw-event read and export have no accepted access policy (PA-B06, PA-B07):
   * every request is refused and audited, whatever the caller holds.
   */
  async requestRestricted(
    reader: ProductAnalyticsReader,
    action:
      typeof productAnalyticsAccessActions.rawRead | typeof productAnalyticsAccessActions.export,
  ): Promise<ProductAnalyticsReadResult> {
    const nowUtc = this.clock.now().toISOString();
    await this.db.runTransaction((tx) => {
      this.#audit(tx, reader, action, {
        outcome: 'deny',
        reason: 'policy_unavailable',
        fromDayUtc: null,
        toDayUtc: null,
        nowUtc,
      });
      return Promise.resolve();
    });
    return { kind: 'refused', code: 'policy_unavailable' };
  }

  #policy(now: Date): ProductAnalyticsCollectionPolicy | null {
    const nowUtc = now.toISOString();
    return acceptedProductAnalyticsPolicy(this.policy.effective(nowUtc), nowUtc);
  }

  #admissible(
    event: ProductAnalyticsEvent,
    policy: ProductAnalyticsCollectionPolicy,
    now: Date,
  ): 'rejected_policy' | 'rejected_late' | null {
    if (
      event.policyRevision !== policy.policyRevision ||
      !policy.eventNames.includes(event.eventName)
    )
      return 'rejected_policy';
    const occurred = Date.parse(event.occurredAtUtc);
    if (
      occurred > now.getTime() + productAnalyticsLimits.futureSkewMinutes * 60 * 1000 ||
      occurred < now.getTime() - policy.acceptanceWindowHours * hourMs
    )
      return 'rejected_late';
    return null;
  }

  #flag(tx: Transaction, flagId: string): Promise<boolean> {
    return new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(flagId, tx);
  }

  async #sender(tx: Transaction, hint: BookingAccessHint, now: Date): Promise<string | null> {
    try {
      const decision = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        now,
      );
      return decision.allowed ? decision.userId : null;
    } catch (error) {
      if (error instanceof TypeError) return null;
      throw error;
    }
  }

  async #allowed(
    tx: Transaction,
    reader: ProductAnalyticsReader,
    action: ProductAnalyticsAccessAction,
    nowUtc: string,
  ): Promise<boolean> {
    if (!idPattern.test(reader.userId) || !idPattern.test(reader.sessionId)) return false;
    const [account, session, grant] = await tx.getAll(
      this.db.collection(identity.accounts).doc(reader.userId),
      this.db.collection(identity.sessions).doc(reader.sessionId),
      this.db.collection(cols.accessAuthority).doc(reader.userId),
    );
    try {
      assertCurrentSession(
        session!.data() as Parameters<typeof assertCurrentSession>[0],
        account!.data() as Parameters<typeof assertCurrentSession>[1],
        nowUtc,
      );
    } catch {
      return false;
    }
    const g = grant!.data();
    return (
      g?.userId === reader.userId &&
      g.source === productAnalyticsAuthoritySource &&
      g.revoked !== true &&
      g.marketId === 'LV' &&
      typeof g.expiresAtUtc === 'string' &&
      Date.parse(g.expiresAtUtc) > Date.parse(nowUtc) &&
      Array.isArray(g.actions) &&
      g.actions.includes(action)
    );
  }

  #audit(
    tx: Transaction,
    reader: ProductAnalyticsReader,
    action: ProductAnalyticsAccessAction,
    entry: {
      readonly outcome: 'allow' | 'deny';
      readonly reason: string;
      readonly fromDayUtc: string | null;
      readonly toDayUtc: string | null;
      readonly nowUtc: string;
    },
  ): void {
    const ref: DocumentReference = this.db.collection(cols.accessAudit).doc(randomUUID());
    tx.create(ref, {
      schemaVersion: 1,
      actorId: idPattern.test(reader.userId) ? reader.userId : null,
      action,
      outcome: entry.outcome,
      reason: entry.reason,
      fromDayUtc: entry.fromDayUtc,
      toDayUtc: entry.toDayUtc,
      atUtc: entry.nowUtc,
      environment: 'local',
      policy: productAnalyticsAccessPolicy,
    });
  }
}

/**
 * Bootstrap of the test-only reader registry: called by the Emulator test or
 * stand seed, never by a command. It creates an entry and never rewrites one.
 */
export async function grantProductAnalyticsAccess(
  db: Firestore,
  input: {
    readonly userId: string;
    readonly actions: readonly ProductAnalyticsAccessAction[];
    readonly grantedAtUtc: string;
    readonly expiresAtUtc: string;
  },
): Promise<void> {
  assertContentEmulatorContext(db);
  await db
    .collection(cols.accessAuthority)
    .doc(input.userId)
    .create({
      userId: input.userId,
      source: productAnalyticsAuthoritySource,
      marketId: 'LV',
      actions: [...input.actions],
      grantedAtUtc: input.grantedAtUtc,
      expiresAtUtc: input.expiresAtUtc,
    });
}
