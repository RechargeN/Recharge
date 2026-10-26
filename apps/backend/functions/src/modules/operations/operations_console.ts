import { randomUUID } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';

import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../platform/config/firestore_feature_flag_gate.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { assertCurrentSession } from '../identity_publisher/domain/session.js';
import { identityAuthorityCollections as identity } from '../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { emergencySwitchState } from './emergency_switch.js';
import { admitRestoredCopy, type RestoreAdmission } from './restore_admission.js';
import { operationalFamily, type OperationalFamilyId } from './operational_task_registry.js';
import type {
  OperationsFamilyPort,
  OperationsReconcileReport,
  OperationsReplayResult,
  OperationsTaskView,
} from './operations_ports.js';
import { validOperatorDecision } from './operations_ports.js';

export const operationsCollections = Object.freeze({
  /** Emulator test registry of operators; production authority is OB-01. */
  authority: 'operationsOperatorAuthority',
  audit: 'operationsOperatorAudit',
});

export const operationsAuthoritySource = 'test-only-emulator-stand-bootstrap';
export const operationsPolicy = 'test-only-l2-operations-v1';

export const operationsActions = Object.freeze({
  inspect: 'ops.inspect',
  replay: 'ops.replay',
  reconcile: 'ops.reconcile',
  disable: 'ops.disable',
  enable: 'ops.enable',
  /** Admission of an isolated restored copy; scoped to the pseudo-family `restore`. */
  restore: 'ops.restore',
});
export type OperationsAction = (typeof operationsActions)[keyof typeof operationsActions];

/** A verified staff Session subject; a trusted internal input, never client claims. */
export interface OperationsOperator {
  readonly userId: string;
  readonly sessionId: string;
}

export interface OperationsDecisionInput {
  readonly decisionId: string;
  readonly reason: string;
  readonly correlationId: string;
}

export type OperationsConsoleRefusal =
  | 'invalid_contract'
  | 'not_supported'
  | 'access_denied'
  /** Authority or audit could not be read or written: nothing was done. */
  | 'audit_or_authority_unavailable'
  | 'not_found'
  | 'decision_conflict';

export type OperationsConsoleResult<T> =
  | { readonly kind: 'succeeded'; readonly data: T }
  | { readonly kind: 'rejected'; readonly code: OperationsConsoleRefusal };

const rejected = (code: OperationsConsoleRefusal) => ({ kind: 'rejected' as const, code });
const idPattern = /^[A-Za-z0-9_-]{1,128}$/u;
const taskIdPattern = /^[A-Za-z0-9_.:-]{1,200}$/u;

/**
 * L2 operations console (OPS-L2 §3.6, §4). The only operator entry for inspect,
 * replay, reconcile and containment. Every call rechecks the current Session
 * and the server registry entry for the family and action, and writes an audit
 * record in the same transaction as the authorization; when either cannot be
 * read or written nothing happens. Effects stay with the owner through its
 * port; the console writes only its audit and the family's emergency switch.
 * Local Emulator only; no callable, UI or generic patch.
 */
export class OperationsConsole {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
    private readonly ports: Partial<Record<OperationalFamilyId, OperationsFamilyPort>>,
    /** Test-only fault injection before the audit write, never a client parameter. */
    private readonly beforeAudit: () => void = () => {},
  ) {
    assertContentEmulatorContext(db);
  }

  async inspect(
    operator: OperationsOperator,
    familyId: string,
    taskId: string,
  ): Promise<OperationsConsoleResult<OperationsTaskView>> {
    const port = this.#port(familyId, 'inspect');
    if (port === undefined || !taskIdPattern.test(taskId)) return rejected('not_supported');
    const access = await this.#authorize(operator, operationsActions.inspect, familyId, taskId);
    if (access !== 'allow') return rejected(access);
    const view = await port.inspect(taskId, this.#now());
    return view === undefined ? rejected('not_found') : { kind: 'succeeded', data: view };
  }

  async replay(
    operator: OperationsOperator,
    familyId: string,
    taskId: string,
    decision: OperationsDecisionInput,
  ): Promise<OperationsConsoleResult<{ readonly result: OperationsReplayResult }>> {
    const port = this.#port(familyId, 'replay');
    if (port === undefined) return rejected('not_supported');
    const full = { ...decision, actorId: operator.userId };
    if (!taskIdPattern.test(taskId) || !validOperatorDecision(full))
      return rejected('invalid_contract');
    const access = await this.#authorize(
      operator,
      operationsActions.replay,
      familyId,
      taskId,
      decision.decisionId,
    );
    if (access !== 'allow') return rejected(access);
    const result = await port.replay(taskId, this.#now(), full);
    await this.#outcome(operator, operationsActions.replay, familyId, taskId, result, decision);
    return { kind: 'succeeded', data: { result } };
  }

  async reconcile(
    operator: OperationsOperator,
    familyId: string,
  ): Promise<OperationsConsoleResult<OperationsReconcileReport>> {
    const port = this.#port(familyId, 'reconcile');
    if (port?.reconcile === undefined) return rejected('not_supported');
    const access = await this.#authorize(operator, operationsActions.reconcile, familyId, null);
    if (access !== 'allow') return rejected(access);
    const report = await port.reconcile(this.#now());
    await this.#outcome(
      operator,
      operationsActions.reconcile,
      familyId,
      null,
      report.complete ? 'complete' : `findings:${String(report.findings.length)}`,
    );
    return { kind: 'succeeded', data: report };
  }

  /**
   * Emergency disable (`contained: true`) or re-enable of a family. A new
   * immutable switch revision and the pointer move in the same transaction as
   * the authorization and audit; the queue, receipts and audit stay. The same
   * decision answers with its stored result.
   */
  async setContainment(
    operator: OperationsOperator,
    familyId: string,
    contained: boolean,
    decision: OperationsDecisionInput,
  ): Promise<OperationsConsoleResult<{ readonly result: 'contained' | 'reopened' | 'unchanged' }>> {
    const switchId = operationalFamily(familyId)?.emergencySwitchId ?? null;
    if (switchId === null) return rejected('not_supported');
    if (!validOperatorDecision({ ...decision, actorId: operator.userId }))
      return rejected('invalid_contract');
    const action = contained ? operationsActions.disable : operationsActions.enable;
    const nowUtc = this.#now();
    try {
      return await this.db.runTransaction(async (tx) => {
        const allowed = await this.#allowed(tx, operator, action, familyId, nowUtc);
        const decisionRef = this.db
          .collection(operationsCollections.audit)
          .doc(`d_${decision.decisionId}`);
        const prior = allowed ? (await tx.get(decisionRef)).data() : undefined;
        const key = featureFlagKey('local', 'LV', switchId);
        const pointerRef = this.db.collection(featureFlagPointerCollection).doc(key);
        const pointer = allowed ? (await tx.get(pointerRef)).data() : undefined;
        const state = allowed ? await emergencySwitchState(this.db, switchId, tx) : 'contained';
        let revision = typeof pointer?.activeRevision === 'number' ? pointer.activeRevision + 1 : 1;
        if (allowed && prior === undefined && (state === 'contained') !== contained) {
          for (let probe = 0; probe < 16; probe += 1, revision += 1) {
            const existing = await tx.get(this.#revisionRef(key, revision));
            if (!existing.exists) break;
          }
        }
        this.beforeAudit();
        if (!allowed) {
          this.#audit(tx, operator, action, familyId, null, 'deny', 'authorize', null, nowUtc);
          return rejected('access_denied');
        }
        if (prior !== undefined) {
          return prior.familyId === familyId && prior.action === action
            ? { kind: 'succeeded' as const, data: { result: prior.result as 'contained' } }
            : rejected('decision_conflict');
        }
        const result =
          (state === 'contained') === contained
            ? 'unchanged'
            : contained
              ? 'contained'
              : 'reopened';
        if (result !== 'unchanged') {
          tx.create(this.#revisionRef(key, revision), {
            schemaVersion: 1,
            revision,
            environmentId: 'local',
            marketId: 'LV',
            capabilityId: switchId,
            enabled: contained,
            createdAtUtc: nowUtc,
            decisionId: decision.decisionId,
          });
          tx.set(pointerRef, {
            key,
            activeRevision: revision,
            pointerRevision:
              (typeof pointer?.pointerRevision === 'number' ? pointer.pointerRevision : 0) + 1,
          });
        }
        tx.create(decisionRef, {
          ...this.#entry(operator, action, familyId, null, 'allow', 'decision', result, nowUtc),
          decisionId: decision.decisionId,
          reason: decision.reason,
          correlationId: decision.correlationId,
        });
        return { kind: 'succeeded' as const, data: { result } };
      });
    } catch {
      return rejected('audit_or_authority_unavailable');
    }
  }

  /**
   * Restore admission (OPS-L2 §6): authorized and audited like any operator
   * action; the decision and its counters go to the audit without subject IDs.
   */
  async admitRestore(
    operator: OperationsOperator,
    input: Omit<Parameters<typeof admitRestoredCopy>[0], 'clock'>,
  ): Promise<OperationsConsoleResult<RestoreAdmission>> {
    const access = await this.#authorize(operator, operationsActions.restore, 'restore', null);
    if (access !== 'allow') return rejected(access);
    const admission = await admitRestoredCopy({ ...input, clock: this.clock });
    await this.#outcome(
      operator,
      operationsActions.restore,
      'restore',
      input.restored.databaseId,
      admission.state === 'closed' ? `closed:${admission.reason}` : admission.state,
    );
    return { kind: 'succeeded', data: admission };
  }

  #port(familyId: string, capability: 'inspect' | 'replay' | 'reconcile') {
    const family = operationalFamily(familyId);
    if (family === undefined || !family.console[capability]) return undefined;
    return this.ports[family.id];
  }

  #now(): string {
    return this.clock.now().toISOString();
  }

  #revisionRef(key: string, revision: number) {
    return this.db
      .collection(featureFlagRevisionCollection)
      .doc(featureFlagRevisionDocumentId(key, revision));
  }

  async #authorize(
    operator: OperationsOperator,
    action: OperationsAction,
    familyId: string,
    ref: string | null,
    decisionId: string | null = null,
  ): Promise<'allow' | 'access_denied' | 'audit_or_authority_unavailable'> {
    const nowUtc = this.#now();
    try {
      return await this.db.runTransaction(async (tx) => {
        const allowed = await this.#allowed(tx, operator, action, familyId, nowUtc);
        this.beforeAudit();
        this.#audit(
          tx,
          operator,
          action,
          familyId,
          ref,
          allowed ? 'allow' : 'deny',
          'authorize',
          decisionId,
          nowUtc,
        );
        return allowed ? ('allow' as const) : ('access_denied' as const);
      });
    } catch {
      return 'audit_or_authority_unavailable';
    }
  }

  /** The result of an authorized call; a lost write leaves the authorization record. */
  async #outcome(
    operator: OperationsOperator,
    action: OperationsAction,
    familyId: string,
    ref: string | null,
    result: string,
    decision?: OperationsDecisionInput,
  ): Promise<void> {
    try {
      await this.db
        .collection(operationsCollections.audit)
        .doc(randomUUID())
        .create({
          ...this.#entry(operator, action, familyId, ref, 'allow', 'outcome', result, this.#now()),
          ...(decision === undefined
            ? {}
            : {
                decisionId: decision.decisionId,
                reason: decision.reason,
                correlationId: decision.correlationId,
              }),
        });
    } catch {
      // The authorization record stays; the owner's own decision record holds the result.
    }
  }

  async #allowed(
    tx: Transaction,
    operator: OperationsOperator,
    action: OperationsAction,
    familyId: string,
    nowUtc: string,
  ): Promise<boolean> {
    if (!idPattern.test(operator.userId) || !idPattern.test(operator.sessionId)) return false;
    const [account, session, grant] = await tx.getAll(
      this.db.collection(identity.accounts).doc(operator.userId),
      this.db.collection(identity.sessions).doc(operator.sessionId),
      this.db.collection(operationsCollections.authority).doc(operator.userId),
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
      g?.userId === operator.userId &&
      g.source === operationsAuthoritySource &&
      g.revoked !== true &&
      typeof g.expiresAtUtc === 'string' &&
      Date.parse(g.expiresAtUtc) > Date.parse(nowUtc) &&
      Array.isArray(g.scopes) &&
      g.scopes.some((scope: unknown) => {
        if (typeof scope !== 'object' || scope === null) return false;
        const s = scope as Record<string, unknown>;
        return (
          s.familyId === familyId &&
          s.marketId === 'LV' &&
          Array.isArray(s.actions) &&
          s.actions.includes(action)
        );
      })
    );
  }

  #audit(
    tx: Transaction,
    operator: OperationsOperator,
    action: OperationsAction,
    familyId: string,
    ref: string | null,
    outcome: 'allow' | 'deny',
    phase: 'authorize' | 'outcome' | 'decision',
    decisionId: string | null,
    nowUtc: string,
  ): void {
    tx.create(this.db.collection(operationsCollections.audit).doc(randomUUID()), {
      ...this.#entry(operator, action, familyId, ref, outcome, phase, null, nowUtc),
      decisionId,
    });
  }

  #entry(
    operator: OperationsOperator,
    action: OperationsAction,
    familyId: string,
    ref: string | null,
    outcome: 'allow' | 'deny',
    phase: 'authorize' | 'outcome' | 'decision',
    result: string | null,
    nowUtc: string,
  ) {
    return {
      schemaVersion: 1,
      actorId: operator.userId,
      sessionId: operator.sessionId,
      action,
      familyId,
      ref,
      outcome,
      phase,
      result,
      atUtc: nowUtc,
      environment: 'local',
      policy: operationsPolicy,
    };
  }
}

/**
 * Bootstrap of the test-only operator registry: called by the Emulator test
 * or stand seed, never by a command. It creates an entry and never rewrites one.
 */
export async function grantOperationsAuthority(
  db: Firestore,
  input: {
    readonly userId: string;
    readonly scopes: readonly { readonly familyId: string; readonly actions: readonly string[] }[];
    readonly grantedAtUtc: string;
    readonly expiresAtUtc: string;
  },
): Promise<void> {
  assertContentEmulatorContext(db);
  await db
    .collection(operationsCollections.authority)
    .doc(input.userId)
    .create({
      userId: input.userId,
      source: operationsAuthoritySource,
      scopes: input.scopes.map((scope) => ({ ...scope, marketId: 'LV' })),
      grantedAtUtc: input.grantedAtUtc,
      expiresAtUtc: input.expiresAtUtc,
    });
}
