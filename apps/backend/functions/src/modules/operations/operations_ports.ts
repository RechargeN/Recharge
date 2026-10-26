/**
 * L2 ports between the operations console and the owning modules (OPS-L2 §3–4).
 * The owner implements them over its own records; the console never reads or
 * writes a domain collection. Views carry codes, counters and opaque task IDs
 * only: no payload, error text, recipient or other personal data.
 */
export type OperationsFailureClass = 'permanent' | 'transient' | 'unknown';

export interface OperationsFailureEntry {
  readonly attempt: number;
  readonly failureClass: OperationsFailureClass;
  readonly code: string;
  readonly atUtc: string;
}

export type OperationsTaskState =
  | 'pending'
  | 'in_flight'
  /** An attempt started and its lease expired without a recorded result. */
  | 'unknown'
  | 'retry_scheduled'
  | 'done'
  | 'dead_letter';

export interface OperationsTaskView {
  readonly taskId: string;
  readonly state: OperationsTaskState;
  readonly storedStatus: string;
  readonly attempts: number;
  readonly attemptBudget: number;
  readonly failureClass: OperationsFailureClass | null;
  readonly failureCode: string | null;
  /** The first recorded failure; a replay never overwrites it. */
  readonly firstFailure: OperationsFailureEntry | null;
  readonly failureHistory: readonly OperationsFailureEntry[];
  readonly replayCount: number;
  readonly nextAttemptAtUtc: string | null;
}

export type OperationsReplayResult =
  | 'requeued'
  /** The same operator decision was already applied. */
  | 'replayed'
  | 'not_found'
  | 'not_dead_letter'
  /** Retrying cannot change the outcome; repair the source through K3. */
  | 'permanent_rejection'
  /** The source no longer matches what the task was created from. */
  | 'payload_changed'
  | 'family_contained'
  | 'replay_exhausted'
  | 'expired'
  | 'decision_conflict';

export interface OperationsOperatorDecision {
  readonly decisionId: string;
  readonly actorId: string;
  /** A short code such as `ops.transient-store-outage`, never free text. */
  readonly reason: string;
  readonly correlationId: string;
}

export interface OperationsReconcileFinding {
  readonly code: string;
  readonly ref: string;
}

export interface OperationsReconcileReport {
  /** True only when the pass reached the end and found nothing open. */
  readonly complete: boolean;
  readonly scanned: number;
  /** Tasks handed back to the owner's own delivery path. */
  readonly redispatched: number;
  /** Open problems; any of them keeps the report incomplete. */
  readonly findings: readonly OperationsReconcileFinding[];
  /** Problems the owner path resolved in this pass, kept visible. */
  readonly repaired?: readonly OperationsReconcileFinding[];
}

export interface OperationsFamilyPort {
  inspect(taskId: string, nowUtc: string): Promise<OperationsTaskView | undefined>;
  replay(
    taskId: string,
    nowUtc: string,
    decision: OperationsOperatorDecision,
  ): Promise<OperationsReplayResult>;
  reconcile?(nowUtc: string): Promise<OperationsReconcileReport>;
}

/** Bounded failure history: the first entry is kept by `firstFailure`, the rest roll. */
export const operationsFailureHistoryLimit = 20;

export function appendFailure(
  history: readonly OperationsFailureEntry[] | undefined,
  entry: OperationsFailureEntry,
): OperationsFailureEntry[] {
  return [...(history ?? []), entry].slice(-operationsFailureHistoryLimit);
}

const reasonPattern = /^[a-z][a-z0-9._-]{2,95}$/u;
const idPattern = /^[A-Za-z0-9_-]{1,128}$/u;

export function validOperatorDecision(decision: OperationsOperatorDecision): boolean {
  return (
    idPattern.test(decision.decisionId) &&
    idPattern.test(decision.actorId) &&
    reasonPattern.test(decision.reason) &&
    decision.correlationId.length >= 8 &&
    decision.correlationId.length <= 128
  );
}
