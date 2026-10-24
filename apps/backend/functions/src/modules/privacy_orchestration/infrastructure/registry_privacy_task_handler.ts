import type { Firestore } from 'firebase-admin/firestore';
import type { PrivacyPolicyBlocker } from '../domain/privacy_domain_task.js';
import { privacyRegistryRows, privacyPolicyRevision } from '../domain/privacy_writer_registry.js';
import {
  sweepPrivacySubject,
  type PrivacyApplier,
  type PrivacyFaultPoint,
  type PrivacySweepFamily,
} from './firestore_privacy_subject_sweep.js';

/** What one domain run tells the runner; it never claims more than happened. */
export type PrivacyDomainOutcome =
  | {
      readonly kind: 'succeeded';
      readonly evidence: {
        readonly outcome: 'completed' | 'retained_legal_hold';
        readonly retainedCount: number;
      };
    }
  | {
      readonly kind: 'blocked';
      readonly blockedCodes: readonly PrivacyPolicyBlocker[];
      readonly retainedCount: number;
    }
  | { readonly kind: 'progress' }
  | { readonly kind: 'retryableFailure' }
  | { readonly kind: 'failed' }
  | { readonly kind: 'lease_lost' };

export interface PrivacyDomainRun {
  readonly taskType: 'access' | 'erasure' | 'restriction';
  readonly subjectId: string;
  readonly taskId: string;
  readonly leaseOwner: string;
  readonly nowUtc: string;
  readonly fault?: (point: PrivacyFaultPoint) => void;
  readonly maxPages?: number;
  readonly pageSize?: number;
}

export interface PrivacyDomainHandler {
  handle(run: PrivacyDomainRun): Promise<PrivacyDomainOutcome>;
}

/**
 * L1 handler driven by the writer registry: it sweeps every locatable family of
 * one domain, applies the owning module's appliers to `delete` rows, leaves
 * held records untouched and reports `blocked` rows and families that cannot be
 * found by subject with their policy blocker. Restriction relies on the
 * Identity restriction the runner applies first; access counts records only.
 */
export class RegistryPrivacyTaskHandler implements PrivacyDomainHandler {
  constructor(
    private readonly db: Firestore,
    private readonly domainId: string,
    /** Owner appliers keyed by `collection` or `collection:subjectField`. */
    private readonly appliers: Readonly<Record<string, PrivacyApplier>> = {},
  ) {}

  async handle(run: PrivacyDomainRun): Promise<PrivacyDomainOutcome> {
    if (run.taskType === 'restriction')
      return { kind: 'succeeded', evidence: { outcome: 'completed', retainedCount: 0 } };
    const rows = privacyRegistryRows(this.domainId);
    const families: PrivacySweepFamily[] = rows
      .filter(
        (row): row is typeof row & { readonly subjectField: string } =>
          row.subjectField !== null &&
          (row.erasure.kind === 'delete' ||
            row.erasure.kind === 'anonymize' ||
            row.erasure.kind === 'blocked'),
      )
      .map((row) => {
        const applier =
          this.appliers[`${row.collection}:${row.subjectField}`] ?? this.appliers[row.collection];
        return {
          collection: row.collection,
          subjectField: row.subjectField,
          rule: row.erasure,
          ...(applier === undefined ? {} : { applier }),
        };
      });
    // Families nobody can find by subject are never reported as erased.
    const unlocated = rows.flatMap((row) =>
      row.subjectField === null && row.erasure.kind === 'blocked' ? [row.erasure.blocker] : [],
    );
    try {
      const result = await sweepPrivacySubject({
        db: this.db,
        taskId: run.taskId,
        leaseOwner: run.leaseOwner,
        domainId: this.domainId,
        subjectId: run.subjectId,
        mode: run.taskType === 'access' ? 'access' : 'erasure',
        policyRevision: privacyPolicyRevision,
        nowUtc: run.nowUtc,
        families,
        ...(run.fault === undefined ? {} : { fault: run.fault }),
        ...(run.maxPages === undefined ? {} : { maxPages: run.maxPages }),
        ...(run.pageSize === undefined ? {} : { pageSize: run.pageSize }),
      });
      if (result.kind === 'retry') return { kind: 'retryableFailure' };
      if (result.kind !== 'done') return result;
      if (run.taskType === 'access')
        return { kind: 'succeeded', evidence: { outcome: 'completed', retainedCount: 0 } };
      const blockedCodes = [...new Set([...result.blockedCodes, ...unlocated])].sort();
      if (blockedCodes.length > 0)
        return { kind: 'blocked', blockedCodes, retainedCount: result.retainedCount };
      return {
        kind: 'succeeded',
        evidence: {
          outcome: result.retainedCount > 0 ? 'retained_legal_hold' : 'completed',
          retainedCount: result.retainedCount,
        },
      };
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('privacy_fault')) throw error;
      return { kind: 'retryableFailure' };
    }
  }
}
