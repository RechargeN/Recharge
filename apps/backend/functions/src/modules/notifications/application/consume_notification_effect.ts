import { randomUUID } from 'node:crypto';

import type { ServerClock } from '../../../shared/server_clock.js';
import {
  addMsUtc,
  attemptIdFor,
  finishedAttempt,
  minimalReceipt,
  notificationDeliveryConfig,
  retryBackoffMs,
  startedAttempt,
  type DeadLetterReason,
  type DeliveryAttempt,
  type LiveReceipt,
  type NotificationReceipt,
  type PinnedRevisions,
  type ReceiptStatus,
  type SuppressionReason,
} from '../domain/delivery_attempt.js';
import { createInboxItem } from '../domain/inbox_item.js';
import {
  notificationConsumer,
  notificationEffectSha256,
  notificationIdFor,
  notificationReceiptId,
  parseNotificationEffect,
  type NotificationEffect,
} from '../domain/notification_effect.js';
import {
  defaultNotificationPolicies,
  inAppDecision,
  PreferencesUnreadable,
  type NotificationPolicyRegistry,
} from '../domain/notification_policy.js';
import {
  defaultNotificationTemplates,
  type NotificationTemplateRegistry,
} from '../domain/notification_templates.js';
import type { NotificationsStore, NotificationsTransaction } from '../domain/repositories.js';

/** A failure that retrying cannot fix: the effect is dead-lettered at once. */
export class NotificationPermanentFailure extends Error {
  constructor(readonly code: 'item_conflict' | 'template_unavailable' | 'policy_unavailable') {
    super(code);
  }
}

export interface NotificationClaim {
  readonly receiptId: string;
  readonly leaseId: string;
  readonly attemptNumber: number;
  readonly effect: NotificationEffect;
  readonly pinned: PinnedRevisions;
}

export type ClaimResult =
  | Readonly<{ kind: 'claimed'; claim: NotificationClaim }>
  | Readonly<{ kind: 'not_dispatchable' }>
  | Readonly<{ kind: 'duplicate'; status: ReceiptStatus }>
  | Readonly<{ kind: 'busy' | 'not_due' | 'dead_lettered' | 'payload_conflict' }>
  | Readonly<{ kind: 'suppressed'; reason: SuppressionReason }>
  | Readonly<{ kind: 'expired' }>;

export type CompleteResult =
  | Readonly<{ kind: 'created'; notificationId: string }>
  | Readonly<{ kind: 'suppressed'; reason: SuppressionReason }>
  | Readonly<{ kind: 'expired' }>
  | Readonly<{ kind: 'stale' }>;

export type FailResult = Readonly<{ kind: 'retry_scheduled' | 'dead_lettered' | 'stale' }>;

export type ConsumeOutcome =
  | 'not_dispatchable'
  | 'duplicate'
  | 'busy'
  | 'not_due'
  | 'dead_lettered'
  | 'payload_conflict'
  | 'created'
  | 'suppressed'
  | 'expired'
  | 'retry_scheduled'
  | 'stale'
  | 'failed_unrecorded';

export interface NotificationConsumerDependencies {
  readonly store: NotificationsStore;
  readonly clock: ServerClock;
  readonly policies?: NotificationPolicyRegistry;
  readonly templates?: NotificationTemplateRegistry;
  readonly newLeaseId?: () => string;
}

function failureCode(error: unknown): string {
  if (error instanceof PreferencesUnreadable) return 'preferences_unreadable';
  const code = (error as { code?: unknown } | null)?.code;
  if (code === 14 || code === 'unavailable' || code === 'UNAVAILABLE') return 'store_unavailable';
  if (code === 4 || code === 'deadline-exceeded') return 'store_deadline';
  if (code === 10 || code === 'aborted') return 'store_aborted';
  return 'unexpected';
}

/**
 * F1 consumer of Booking notification obligations (BCK-13 §11, F1 §5).
 *
 * Tx1 claim persists the attempt and a lease before any inbox work, so a failed
 * or crashed completion is never lost: Tx3 records the failure, or a later claim
 * after the lease expires records it as `abandoned`. Tx2 completes atomically
 * (inbox record + terminal receipt + attempt) and refuses a stale lease. The
 * template and policy revisions are pinned at the first claim and reused by every
 * retry and replay.
 */
export class NotificationEffectConsumer {
  readonly #store: NotificationsStore;
  readonly #clock: ServerClock;
  readonly #policies: NotificationPolicyRegistry;
  readonly #templates: NotificationTemplateRegistry;
  readonly #newLeaseId: () => string;

  constructor(dependencies: NotificationConsumerDependencies) {
    this.#store = dependencies.store;
    this.#clock = dependencies.clock;
    this.#policies = dependencies.policies ?? defaultNotificationPolicies;
    this.#templates = dependencies.templates ?? defaultNotificationTemplates;
    this.#newLeaseId = dependencies.newLeaseId ?? randomUUID;
  }

  async consume(eventId: string, data: unknown): Promise<ConsumeOutcome> {
    const claimed = await this.claim(eventId, data);
    if (claimed.kind !== 'claimed') return claimed.kind;
    try {
      return (await this.complete(claimed.claim)).kind;
    } catch (error) {
      try {
        return (await this.fail(claimed.claim, error)).kind;
      } catch {
        // The claim and its started attempt stay; the lease expiry hands the
        // effect to the next worker, which records this attempt as abandoned.
        return 'failed_unrecorded';
      }
    }
  }

  /** Tx1: persists the claim, its lease and a started attempt, or a terminal outcome. */
  claim(eventId: string, data: unknown): Promise<ClaimResult> {
    const parsed = parseNotificationEffect(eventId, data);
    if (parsed.kind === 'not_dispatchable') return Promise.resolve({ kind: 'not_dispatchable' });
    const receiptId = notificationReceiptId(eventId);
    const now = this.#clock.now().toISOString();
    return this.#store.transact(async (tx) => {
      const existing = await tx.receipt(receiptId);
      if (existing !== undefined) {
        if (existing.shape === 'minimal' || existing.status === 'created')
          return { kind: 'duplicate', status: existing.status };
        if (existing.status === 'dead_lettered') return { kind: 'dead_lettered' };
        if (
          existing.status === 'claimed' &&
          Date.parse(existing.leaseExpiresAtUtc ?? now) > Date.parse(now)
        )
          return { kind: 'busy' };
        if (
          existing.status === 'retry_scheduled' &&
          Date.parse(existing.nextAttemptAtUtc ?? now) > Date.parse(now)
        )
          return { kind: 'not_due' };
      }
      const live = existing?.shape === 'live' ? existing : undefined;
      const abandoned = await this.#abandonedAttempt(tx, live, now);

      if (parsed.kind === 'invalid') {
        const attemptNumber = (live?.attemptCount ?? 0) + 1;
        if (abandoned !== undefined) tx.putAttempt(abandoned);
        tx.putReceipt(
          this.#liveReceipt({
            receiptId,
            eventId,
            existing: live,
            status: 'dead_lettered',
            reason: parsed.code,
            attemptCount: attemptNumber,
            now,
          }),
        );
        tx.putAttempt(
          finishedAttempt(
            startedAttempt({ receiptId, attemptNumber, leaseId: 'poison', startedAtUtc: now }),
            {
              status: 'failed',
              failureClass: 'permanent',
              failureCode: parsed.code,
              finishedAtUtc: now,
            },
          ),
        );
        return { kind: 'dead_lettered' };
      }

      const effect = parsed.effect;
      const payloadSha256 = notificationEffectSha256(effect);
      if (
        live?.payloadSha256 !== undefined &&
        live.payloadSha256 !== null &&
        live.payloadSha256 !== payloadSha256
      )
        return { kind: 'payload_conflict' };
      const recipient = await tx.recipientStatus(effect.recipientId);
      if (abandoned !== undefined) tx.putAttempt(abandoned);

      const route = this.#policies.active().route(effect);
      if (route.kind === 'suppress') {
        tx.putReceipt(this.#suppressed(receiptId, route.reason, now, effect));
        return { kind: 'suppressed', reason: route.reason };
      }
      if (recipient !== 'active') {
        const reason = recipient === 'not_found' ? 'recipient_not_found' : 'recipient_restricted';
        tx.putReceipt(this.#suppressed(receiptId, reason, now, effect));
        return { kind: 'suppressed', reason };
      }
      if (Date.parse(now) > Date.parse(effect.deliverUntilUtc)) {
        tx.putReceipt(
          minimalReceipt({
            receiptId,
            status: 'expired',
            reason: null,
            terminalAtUtc: now,
            deliverUntilUtc: effect.deliverUntilUtc,
          }),
        );
        return { kind: 'expired' };
      }
      const attemptNumber = (live?.attemptCount ?? 0) + 1;
      const budget = live?.attemptBudget ?? notificationDeliveryConfig.maxAttempts;
      const pinned = live?.pinned ?? this.#pin(route.category, route.templateKey);
      if (attemptNumber > budget || pinned === undefined) {
        tx.putReceipt(
          this.#liveReceipt({
            receiptId,
            eventId,
            effect,
            payloadSha256,
            existing: live,
            status: 'dead_lettered',
            reason: pinned === undefined ? 'template_unavailable' : 'retry_exhausted',
            attemptCount: live?.attemptCount ?? 0,
            pinned: pinned ?? null,
            now,
          }),
        );
        return { kind: 'dead_lettered' };
      }
      const leaseId = this.#newLeaseId();
      const leaseExpiresAtUtc = addMsUtc(now, notificationDeliveryConfig.leaseMs);
      tx.putReceipt(
        this.#liveReceipt({
          receiptId,
          eventId,
          effect,
          payloadSha256,
          existing: live,
          status: 'claimed',
          reason: null,
          attemptCount: attemptNumber,
          pinned,
          leaseId,
          leaseExpiresAtUtc,
          now,
        }),
      );
      tx.putAttempt(startedAttempt({ receiptId, attemptNumber, leaseId, startedAtUtc: now }));
      return {
        kind: 'claimed',
        claim: { receiptId, leaseId, attemptNumber, effect, pinned },
      };
    });
  }

  /** Tx2: inbox record, terminal receipt and finished attempt, or nothing. */
  complete(claim: NotificationClaim): Promise<CompleteResult> {
    const now = this.#clock.now().toISOString();
    const { effect, pinned, receiptId } = claim;
    const notificationId = notificationIdFor(receiptId);
    return this.#store.transact(async (tx) => {
      const receipt = await tx.receipt(receiptId);
      if (
        receipt === undefined ||
        receipt.shape !== 'live' ||
        receipt.status !== 'claimed' ||
        receipt.leaseId !== claim.leaseId
      )
        return { kind: 'stale' };
      const attempt = await tx.attempt(attemptIdFor(receiptId, claim.attemptNumber));
      const recipient = await tx.recipientStatus(effect.recipientId);
      const preferences = await tx.preferences(effect.recipientId);
      const siblings = await tx.aggregateReceipts(effect.aggregateId);
      const existingItem = await tx.inboxItem(notificationId);
      const finish = (outcome: ReceiptStatus) =>
        tx.putAttempt(
          finishedAttempt(
            attempt ??
              startedAttempt({
                receiptId,
                attemptNumber: claim.attemptNumber,
                leaseId: claim.leaseId,
                startedAtUtc: now,
              }),
            { status: 'succeeded', outcome, finishedAtUtc: now },
          ),
        );

      if (recipient !== 'active' || preferences?.processingRestricted === true) {
        const reason = recipient === 'not_found' ? 'recipient_not_found' : 'recipient_restricted';
        tx.putReceipt(this.#suppressed(receiptId, reason, now, effect, pinned));
        finish('suppressed');
        return { kind: 'suppressed', reason };
      }
      if (Date.parse(now) > Date.parse(effect.deliverUntilUtc)) {
        tx.putReceipt(
          minimalReceipt({
            receiptId,
            status: 'expired',
            reason: null,
            terminalAtUtc: now,
            deliverUntilUtc: effect.deliverUntilUtc,
          }),
        );
        finish('expired');
        return { kind: 'expired' };
      }
      const policy = this.#policies.get(pinned.policyRevision);
      if (policy === undefined) throw new NotificationPermanentFailure('policy_unavailable');
      if (!inAppDecision(policy, preferences, pinned.category).enabled) {
        tx.putReceipt(
          this.#suppressed(
            receiptId,
            'user_preference',
            now,
            effect,
            pinned,
            preferences?.revision,
          ),
        );
        finish('suppressed');
        return { kind: 'suppressed', reason: 'user_preference' };
      }
      if (
        siblings.some(
          (sibling) =>
            sibling.receiptId !== receiptId &&
            sibling.status === 'created' &&
            (sibling.aggregateRevision ?? 0) > effect.aggregateRevision,
        )
      ) {
        tx.putReceipt(this.#suppressed(receiptId, 'superseded', now, effect, pinned));
        finish('suppressed');
        return { kind: 'suppressed', reason: 'superseded' };
      }
      // The receipt is not terminal, so any document under this id is foreign.
      if (existingItem !== undefined) throw new NotificationPermanentFailure('item_conflict');
      if (this.#templates.get(pinned.templateKey, pinned.templateRevision) === undefined)
        throw new NotificationPermanentFailure('template_unavailable');
      const item = createInboxItem({
        notificationId,
        recipientId: effect.recipientId,
        receiptId,
        category: pinned.category,
        templateKey: pinned.templateKey,
        templateRevision: pinned.templateRevision,
        variables:
          effect.reconfirmationDeadlineUtc === undefined
            ? {}
            : { deadline: effect.reconfirmationDeadlineUtc },
        eventContentId: effect.eventContentId,
        bookingId: effect.aggregateId,
        bookingRevision: effect.aggregateRevision,
        occurredAtUtc: effect.occurredAtUtc,
        createdAtUtc: now,
      });
      tx.createInboxItem(item);
      tx.putReceipt({
        ...receipt,
        status: 'created',
        reason: null,
        leaseId: null,
        leaseExpiresAtUtc: null,
        nextAttemptAtUtc: null,
        notificationId,
        preferenceRevision: preferences?.revision ?? null,
        updatedAtUtc: now,
        terminalAtUtc: now,
        expiresAt: item.expiresAt,
      });
      finish('created');
      return { kind: 'created', notificationId };
    });
  }

  /** Tx3: records the failed attempt and schedules a retry or a dead letter. */
  fail(claim: NotificationClaim, error: unknown): Promise<FailResult> {
    const now = this.#clock.now().toISOString();
    const permanent = error instanceof NotificationPermanentFailure;
    const code = permanent ? error.code : failureCode(error);
    return this.#store.transact(async (tx) => {
      const receipt = await tx.receipt(claim.receiptId);
      if (
        receipt === undefined ||
        receipt.shape !== 'live' ||
        receipt.status !== 'claimed' ||
        receipt.leaseId !== claim.leaseId
      )
        return { kind: 'stale' };
      const attempt = await tx.attempt(attemptIdFor(claim.receiptId, claim.attemptNumber));
      tx.putAttempt(
        finishedAttempt(
          attempt ??
            startedAttempt({
              receiptId: claim.receiptId,
              attemptNumber: claim.attemptNumber,
              leaseId: claim.leaseId,
              startedAtUtc: now,
            }),
          {
            status: 'failed',
            failureClass: permanent ? 'permanent' : 'transient',
            failureCode: code,
            finishedAtUtc: now,
          },
        ),
      );
      const exhausted = claim.attemptNumber >= receipt.attemptBudget;
      if (permanent || exhausted) {
        tx.putReceipt({
          ...receipt,
          status: 'dead_lettered',
          reason: permanent ? (code as DeadLetterReason) : 'retry_exhausted',
          leaseId: null,
          leaseExpiresAtUtc: null,
          nextAttemptAtUtc: null,
          updatedAtUtc: now,
        });
        return { kind: 'dead_lettered' };
      }
      tx.putReceipt({
        ...receipt,
        status: 'retry_scheduled',
        leaseId: null,
        leaseExpiresAtUtc: null,
        nextAttemptAtUtc: addMsUtc(now, retryBackoffMs(claim.attemptNumber)),
        updatedAtUtc: now,
      });
      return { kind: 'retry_scheduled' };
    });
  }

  /**
   * Turns an unfinished effect whose relevance window has passed into the
   * terminal minimal `expired` receipt (used by reconciliation).
   */
  expire(receiptId: string): Promise<'expired' | 'not_expired'> {
    const now = this.#clock.now().toISOString();
    return this.#store.transact(async (tx) => {
      const receipt = await tx.receipt(receiptId);
      if (
        receipt === undefined ||
        receipt.shape !== 'live' ||
        receipt.status === 'created' ||
        receipt.deliverUntilUtc === null ||
        Date.parse(now) <= Date.parse(receipt.deliverUntilUtc)
      )
        return 'not_expired';
      const abandoned =
        receipt.status === 'claimed'
          ? await this.#abandonedAttempt(tx, receipt, now, true)
          : undefined;
      if (abandoned !== undefined) tx.putAttempt(abandoned);
      tx.putReceipt(
        minimalReceipt({
          receiptId,
          status: 'expired',
          reason: null,
          terminalAtUtc: now,
          deliverUntilUtc: receipt.deliverUntilUtc,
        }),
      );
      return 'expired';
    });
  }

  async #abandonedAttempt(
    tx: NotificationsTransaction,
    receipt: LiveReceipt | undefined,
    now: string,
    force = false,
  ): Promise<DeliveryAttempt | undefined> {
    if (receipt?.status !== 'claimed') return undefined;
    if (!force && Date.parse(receipt.leaseExpiresAtUtc ?? now) > Date.parse(now)) return undefined;
    const previous = await tx.attempt(attemptIdFor(receipt.receiptId, receipt.attemptCount));
    if (previous === undefined || previous.status !== 'started') return undefined;
    return finishedAttempt(previous, {
      status: 'abandoned',
      failureClass: 'transient',
      failureCode: 'lease_expired',
      finishedAtUtc: now,
    });
  }

  #pin(category: PinnedRevisions['category'], templateKey: string): PinnedRevisions | undefined {
    const templateRevision = this.#templates.activeRevision(templateKey);
    if (
      templateRevision === undefined ||
      this.#templates.get(templateKey, templateRevision) === undefined
    )
      return undefined;
    return {
      policyRevision: this.#policies.active().revision,
      category,
      templateKey,
      templateRevision,
    };
  }

  #suppressed(
    receiptId: string,
    reason: SuppressionReason,
    now: string,
    effect: NotificationEffect,
    pinned?: PinnedRevisions,
    preferenceRevision?: number,
  ): NotificationReceipt {
    return minimalReceipt({
      receiptId,
      status: 'suppressed',
      reason,
      terminalAtUtc: now,
      deliverUntilUtc: effect.deliverUntilUtc,
      evidence: {
        policyRevision: pinned?.policyRevision ?? this.#policies.active().revision,
        ...(pinned === undefined ? {} : { templateRevision: pinned.templateRevision }),
        ...(preferenceRevision === undefined ? {} : { preferenceRevision }),
      },
    });
  }

  #liveReceipt(input: {
    readonly receiptId: string;
    readonly eventId: string;
    readonly effect?: NotificationEffect;
    readonly payloadSha256?: string;
    readonly existing: LiveReceipt | undefined;
    readonly status: 'claimed' | 'dead_lettered';
    readonly reason: DeadLetterReason | null;
    readonly attemptCount: number;
    readonly pinned?: PinnedRevisions | null;
    readonly leaseId?: string;
    readonly leaseExpiresAtUtc?: string;
    readonly now: string;
  }): LiveReceipt {
    const effect = input.effect;
    return {
      schemaVersion: 1,
      shape: 'live',
      receiptId: input.receiptId,
      consumer: notificationConsumer.name,
      consumerVersion: notificationConsumer.version,
      status: input.status,
      reason: input.reason,
      eventId: input.eventId,
      eventType: effect?.eventType ?? null,
      aggregateId: effect?.aggregateId ?? null,
      aggregateRevision: effect?.aggregateRevision ?? null,
      recipientId: effect?.recipientId ?? null,
      payloadSha256: input.payloadSha256 ?? null,
      occurredAtUtc: effect?.occurredAtUtc ?? null,
      deliverUntilUtc: effect?.deliverUntilUtc ?? null,
      pinned: input.pinned ?? null,
      attemptCount: input.attemptCount,
      attemptBudget: input.existing?.attemptBudget ?? notificationDeliveryConfig.maxAttempts,
      replayCount: input.existing?.replayCount ?? 0,
      replays: input.existing?.replays ?? [],
      leaseId: input.leaseId ?? null,
      leaseExpiresAtUtc: input.leaseExpiresAtUtc ?? null,
      nextAttemptAtUtc: input.leaseExpiresAtUtc ?? null,
      notificationId: null,
      preferenceRevision: null,
      createdAtUtc: input.existing?.createdAtUtc ?? input.now,
      updatedAtUtc: input.now,
      terminalAtUtc: null,
      expiresAt: null,
    };
  }
}
