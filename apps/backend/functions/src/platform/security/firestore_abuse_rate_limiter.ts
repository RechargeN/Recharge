import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import {
  abusePolicyId,
  abusePolicyRevision,
  abuseRulesFor,
  type AbuseBucketRule,
  type AbuseOperation,
  type AbuseSubjectKind,
} from '../../security/abuse_policy.js';

export const abuseCollections = Object.freeze({
  counters: 'securityRateLimitCounters',
  attempts: 'securityRateLimitAttempts',
  audit: 'securityAudit',
});

export type AbuseRateDecision =
  | Readonly<{
      allowed: true;
      remaining: number;
      policyId: typeof abusePolicyId;
      policyRevision: typeof abusePolicyRevision;
      networkRiskExceeded: boolean;
    }>
  | Readonly<{
      allowed: false;
      retryAfterSeconds: number;
      policyId: typeof abusePolicyId;
      policyRevision: typeof abusePolicyRevision;
      networkRiskExceeded: boolean;
    }>;

export interface AbuseRateRequest {
  readonly operation: AbuseOperation;
  readonly attemptRequestId: string;
  readonly accountId?: string;
  readonly transportIdentityHash?: string;
  readonly installationId: string;
  readonly sessionId?: string;
  readonly networkRiskHash?: string;
  readonly environmentId: 'local';
  readonly marketId: 'LV' | 'EE' | 'LT';
  readonly now: Date;
  readonly correlationId: string;
}

interface StoredCounter {
  readonly schemaVersion: 1;
  readonly policyId: typeof abusePolicyId;
  readonly policyRevision: typeof abusePolicyRevision;
  readonly operation: AbuseOperation;
  readonly subjectKind: AbuseSubjectKind;
  readonly windowSeconds: number;
  readonly timestampsMs: readonly number[];
  readonly updatedAtUtc: string;
  readonly expiresAt: Date;
}

export class FirestoreAbuseRateLimiter {
  constructor(private readonly firestore: Firestore) {}

  consume(input: AbuseRateRequest): Promise<AbuseRateDecision> {
    assertRequest(input);
    return this.firestore.runTransaction(async (transaction) => this.consumeIn(transaction, input));
  }

  private async consumeIn(
    transaction: Transaction,
    input: AbuseRateRequest,
  ): Promise<AbuseRateDecision> {
    const attemptRef = this.firestore
      .collection(abuseCollections.attempts)
      .doc(attemptDocumentId(input));
    const deduplicateAttempt = input.operation !== 'booking.query';
    const rules = abuseRulesFor(input.operation).filter(
      (rule) => subjectFor(rule.subjectKind, input) !== undefined,
    );
    if (rules.length === 0) throw new Error('abuse_policy_unavailable');
    const bucketRefs = rules.map((rule) =>
      this.firestore.collection(abuseCollections.counters).doc(bucketDocumentId(rule, input)),
    );
    const snapshots = await transaction.getAll(
      ...(deduplicateAttempt ? [attemptRef, ...bucketRefs] : bucketRefs),
    );
    const attemptSnapshot = deduplicateAttempt ? snapshots[0] : undefined;
    if (attemptSnapshot?.exists) return assertStoredDecision(attemptSnapshot.data()?.decision);
    const nowMs = input.now.getTime();
    const evaluations = rules.map((rule, index) => {
      const stored = snapshots[index + (deduplicateAttempt ? 1 : 0)]?.data() as
        StoredCounter | undefined;
      assertCounterCompatible(stored, rule, input.operation);
      const cutoff = nowMs - rule.windowSeconds * 1000;
      const recent = (stored?.timestampsMs ?? []).filter(
        (timestamp) => Number.isSafeInteger(timestamp) && timestamp > cutoff && timestamp <= nowMs,
      );
      const exceeded = recent.length >= rule.limit;
      const retryAfterSeconds = exceeded
        ? Math.max(1, Math.ceil(((recent[0] ?? nowMs) + rule.windowSeconds * 1000 - nowMs) / 1000))
        : 0;
      return { rule, recent, exceeded, retryAfterSeconds };
    });
    const denied = evaluations.filter(({ rule, exceeded }) => rule.enforcing && exceeded);
    const networkRiskExceeded = evaluations.some(
      ({ rule, exceeded }) => rule.subjectKind === 'networkRisk' && exceeded,
    );
    const decision: AbuseRateDecision =
      denied.length === 0
        ? {
            allowed: true,
            remaining: Math.min(
              ...evaluations
                .filter(({ rule }) => rule.enforcing)
                .map(({ rule, recent }) => Math.max(0, rule.limit - recent.length - 1)),
            ),
            policyId: abusePolicyId,
            policyRevision: abusePolicyRevision,
            networkRiskExceeded,
          }
        : {
            allowed: false,
            retryAfterSeconds: Math.max(
              ...denied.map(({ retryAfterSeconds }) => retryAfterSeconds),
            ),
            policyId: abusePolicyId,
            policyRevision: abusePolicyRevision,
            networkRiskExceeded,
          };
    for (const [index, evaluation] of evaluations.entries()) {
      const timestampsMs = [...evaluation.recent, nowMs].slice(-evaluation.rule.limit);
      const counter: StoredCounter = {
        schemaVersion: 1,
        policyId: abusePolicyId,
        policyRevision: abusePolicyRevision,
        operation: input.operation,
        subjectKind: evaluation.rule.subjectKind,
        windowSeconds: evaluation.rule.windowSeconds,
        timestampsMs,
        updatedAtUtc: input.now.toISOString(),
        expiresAt: new Date(nowMs + 60 * 60 * 1000),
      };
      transaction.set(bucketRefs[index]!, counter);
    }
    if (deduplicateAttempt) {
      transaction.create(attemptRef, {
        schemaVersion: 1,
        policyId: abusePolicyId,
        policyRevision: abusePolicyRevision,
        operation: input.operation,
        decision,
        createdAtUtc: input.now.toISOString(),
        expiresAt: new Date(nowMs + 7 * 24 * 60 * 60 * 1000),
      });
    }
    if (!decision.allowed || decision.networkRiskExceeded) {
      transaction.create(
        this.firestore.collection(abuseCollections.audit).doc(auditDocumentId(input)),
        {
          schemaVersion: 1,
          eventType: decision.allowed ? 'network_risk_threshold' : 'rate_limited',
          actorRef: opaqueRef(
            'actor',
            input.accountId ?? input.transportIdentityHash ?? 'unresolved',
          ),
          installationRef: opaqueRef('installation', input.installationId),
          operation: input.operation,
          environmentId: input.environmentId,
          marketId: input.marketId,
          policyId: abusePolicyId,
          policyRevision: abusePolicyRevision,
          retryAfterBucket: decision.allowed ? 0 : retryBucket(decision.retryAfterSeconds),
          occurredAtUtc: input.now.toISOString(),
          correlationId: input.correlationId,
        },
      );
    }
    return decision;
  }
}

export function localNetworkRiskHash(rawIp: string | undefined, now: Date): string | undefined {
  if (rawIp === undefined || rawIp.length === 0) return undefined;
  const day = now.toISOString().slice(0, 10);
  return createHash('sha256').update(`local_demo_network_v1|${day}|${rawIp}`, 'utf8').digest('hex');
}

function subjectFor(kind: AbuseSubjectKind, input: AbuseRateRequest): string | undefined {
  if (kind === 'actorInstallation')
    return input.accountId === undefined ? undefined : `${input.accountId}|${input.installationId}`;
  if (kind === 'account') return input.accountId;
  if (kind === 'installation') return input.installationId;
  if (kind === 'session') return input.sessionId;
  if (kind === 'transportIdentity') return input.transportIdentityHash;
  return input.networkRiskHash;
}

function bucketDocumentId(rule: AbuseBucketRule, input: AbuseRateRequest): string {
  return opaqueRef(
    'bucket',
    [
      abusePolicyId,
      input.environmentId,
      input.marketId,
      input.operation,
      rule.subjectKind,
      String(rule.windowSeconds),
      subjectFor(rule.subjectKind, input)!,
    ].join('|'),
  );
}

function attemptDocumentId(input: AbuseRateRequest): string {
  return opaqueRef(
    'attempt',
    `${input.environmentId}|${input.marketId}|${input.operation}|${input.accountId ?? input.transportIdentityHash}|${input.attemptRequestId}`,
  );
}

function auditDocumentId(input: AbuseRateRequest): string {
  return opaqueRef(
    'audit',
    `${input.operation}|${input.accountId ?? input.transportIdentityHash}|${input.attemptRequestId}`,
  );
}

function opaqueRef(domain: string, value: string): string {
  return createHash('sha256').update(`${domain}|${value}`, 'utf8').digest('hex');
}

function retryBucket(seconds: number): number {
  if (seconds <= 10) return 10;
  if (seconds <= 60) return 60;
  if (seconds <= 900) return 900;
  return 3600;
}

function assertCounterCompatible(
  counter: StoredCounter | undefined,
  rule: AbuseBucketRule,
  operation: AbuseOperation,
): void {
  if (counter === undefined) return;
  if (
    counter.schemaVersion !== 1 ||
    counter.policyId !== abusePolicyId ||
    counter.policyRevision !== abusePolicyRevision ||
    counter.operation !== operation ||
    counter.subjectKind !== rule.subjectKind ||
    counter.windowSeconds !== rule.windowSeconds ||
    !Array.isArray(counter.timestampsMs)
  ) {
    throw new Error('abuse_policy_unavailable');
  }
}

function assertRequest(input: AbuseRateRequest): void {
  if (
    input.environmentId !== 'local' ||
    !['LV', 'EE', 'LT'].includes(input.marketId) ||
    !/^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(input.attemptRequestId) ||
    !Number.isFinite(input.now.getTime()) ||
    (input.accountId === undefined && input.transportIdentityHash === undefined)
  ) {
    throw new TypeError('abuse_rate_request_invalid');
  }
}

function assertStoredDecision(value: unknown): AbuseRateDecision {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('abuse_policy_unavailable');
  }
  const decision = value as Record<string, unknown>;
  if (
    typeof decision.allowed !== 'boolean' ||
    decision.policyId !== abusePolicyId ||
    decision.policyRevision !== abusePolicyRevision ||
    typeof decision.networkRiskExceeded !== 'boolean'
  ) {
    throw new Error('abuse_policy_unavailable');
  }
  if (
    decision.allowed === true &&
    (!Number.isSafeInteger(decision.remaining) || Number(decision.remaining) < 0)
  ) {
    throw new Error('abuse_policy_unavailable');
  }
  if (
    decision.allowed === false &&
    (!Number.isSafeInteger(decision.retryAfterSeconds) || Number(decision.retryAfterSeconds) < 1)
  ) {
    throw new Error('abuse_policy_unavailable');
  }
  return value as AbuseRateDecision;
}
