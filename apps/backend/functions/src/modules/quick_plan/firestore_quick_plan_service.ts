import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { sha256Hex } from '../content/domain/published_revision.js';
import { exact, record } from '../library/library_contract.js';
import { isEntityId } from '../../shared/ids.js';
import { FieldPath } from 'firebase-admin/firestore';
import type { PrivacyPlannedEffect } from '../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import {
  hashCommand,
  parseCommand,
  quickPlanCollections as cols,
  quickPlanFlag,
  reject,
  type Result,
  type QuickPlanCommand,
} from './quick_plan_contract.js';

/** Emulator-only Quick Plan authority; no Content/Catalog/Scenario writes. */
export class FirestoreQuickPlanService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
  ) {
    assertContentEmulatorContext(db);
  }
  private async owner(tx: Transaction, hint: BookingAccessHint): Promise<string | null> {
    try {
      const d = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      return d.allowed ? d.userId : null;
    } catch (e) {
      if (e instanceof TypeError) return null;
      throw e;
    }
  }
  private enabled(tx: Transaction) {
    return new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(quickPlanFlag, tx);
  }
  async command(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    const c = parseCommand(raw);
    if (!c) return reject('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const owner = await this.owner(tx, hint);
      if (!owner) return reject('unauthenticated');
      if (owner !== c.ownerContext) return reject('owner_changed');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      if (!['save', 'delete', 'import'].includes(c.commandType))
        return this.accessCommand(tx, owner, c);
      if (c.planOwnerId !== undefined && c.planOwnerId !== owner)
        return reject('permission_denied');
      const ref = this.db.collection(cols.plans).doc(owner + ':' + c.planId);
      const receiptRef = this.db
        .collection(cols.receipts)
        .doc(owner + ':' + sha256Hex(c.idempotencyKey));
      const receipt = (await tx.get(receiptRef)).data();
      const current = record((await tx.get(ref)).data());
      if (receipt)
        return receipt.hash === hashCommand(c)
          ? (receipt.result as Result)
          : reject('idempotency_conflict');
      const revision = Number(current?.revision ?? 0);
      const finish = (result: Result) => {
        tx.create(receiptRef, { ownerId: owner, hash: hashCommand(c), result });
        return result;
      };
      if (current?.status === 'deleted')
        return finish(reject('deleted', { serverRevision: revision }));
      if (c.commandType === 'import' && current)
        return finish(reject('id_collision', { serverRevision: revision }));
      if (c.commandType !== 'delete' && c.expectedRevision !== revision)
        return finish(reject('revision_conflict', { serverRevision: revision }));
      // Delete wins even when a concurrent edit advanced the revision. The ID is terminal.
      const entry =
        c.commandType === 'delete'
          ? this.writeTombstone(tx, ref, owner, c.planId, current)
          : this.writeEntry(tx, ref, owner, current, {
              planId: c.planId,
              revision: revision + 1,
              status: 'active',
              plan: c.plan,
              updatedAtUtc: this.clock.now().toISOString(),
            });
      return finish({ schemaVersion: 1, kind: 'succeeded', entry });
    });
  }
  /**
   * L1 erasure (PB-00): the owner's own delete for a plan nobody else holds.
   * A plan with a pending or accepted invitation is shared and stays (PB-12).
   */
  privacyErasure(
    tx: Transaction,
    ref: FirebaseFirestore.DocumentReference,
    data: Record<string, unknown>,
  ): Promise<PrivacyPlannedEffect> {
    if (data.status === 'deleted') return Promise.resolve({ outcome: 'unchanged' });
    const shared = Object.values(record(data.invitations) ?? {}).some((grant) =>
      ['pending', 'accepted'].includes(String(record(grant)?.status)),
    );
    if (shared) return Promise.resolve({ outcome: { blocked: 'PB-12' } });
    return Promise.resolve({
      outcome: 'erased',
      write: () => {
        this.writeTombstone(tx, ref, String(data.ownerId), String(data.planId), data);
      },
    });
  }
  private writeTombstone(
    tx: Transaction,
    ref: FirebaseFirestore.DocumentReference,
    owner: string,
    planId: string,
    current: Record<string, unknown> | null,
  ) {
    return this.writeEntry(tx, ref, owner, current, {
      planId,
      revision: Number(current?.revision ?? 0) + 1,
      status: 'deleted',
      updatedAtUtc: this.clock.now().toISOString(),
    });
  }
  private writeEntry(
    tx: Transaction,
    ref: FirebaseFirestore.DocumentReference,
    owner: string,
    current: Record<string, unknown> | null,
    entry: Record<string, unknown>,
  ) {
    tx.set(ref, {
      ownerId: owner,
      ...entry,
      ...(current?.invitations ? { invitations: current.invitations } : {}),
    });
    return entry;
  }
  private async accessCommand(
    tx: Transaction,
    actor: string,
    c: QuickPlanCommand,
  ): Promise<Result> {
    const owner = c.planOwnerId!,
      target = c.targetUserId!;
    const ref = this.db.collection(cols.plans).doc(owner + ':' + c.planId);
    const current = record((await tx.get(ref)).data());
    const account = (await tx.get(this.db.collection('identityAccounts').doc(owner))).data();
    if (!current || current.status !== 'active' || account?.status !== 'active')
      return reject('access_denied');
    const managing = ['invite', 'cancel', 'revoke'].includes(c.commandType);
    if ((managing ? actor !== owner : actor !== target) || target === owner)
      return reject('permission_denied');
    const grants = (current.invitations ?? {}) as Record<string, Record<string, unknown>>;
    const grant = grants[target];
    const receiptRef = this.db
      .collection(cols.receipts)
      .doc(actor + ':' + sha256Hex(c.idempotencyKey));
    const receipt = (await tx.get(receiptRef)).data();
    const same = grant?.invitationId === c.invitationId && grant?.generation === c.generation;
    // Invite's intent names the PREVIOUS generation. All replays are fenced by
    // the current invitation before reading a historical receipt.
    const sameInvite =
      c.commandType === 'invite' &&
      grant?.invitationId === c.invitationId &&
      grant?.generation === Number(c.generation) + 1 &&
      ['pending', 'accepted'].includes(String(grant?.status));
    const safeTerminal =
      same &&
      ((c.commandType === 'leave' && grant?.status === 'left') ||
        (c.commandType === 'revoke' && grant?.status === 'revoked') ||
        (c.commandType === 'cancel' && grant?.status === 'cancelled') ||
        (c.commandType === 'decline' && grant?.status === 'declined'));
    if (receipt) {
      if (!(
        sameInvite ||
        safeTerminal ||
        (same && ['pending', 'accepted'].includes(String(grant?.status)))
      ))
        return reject('access_revoked');
      return receipt.hash === hashCommand(c)
        ? (receipt.result as Result)
        : reject('idempotency_conflict');
    }
    let next: Record<string, unknown>;
    if (c.commandType === 'invite') {
      if (sameInvite) return { schemaVersion: 1, kind: 'succeeded', invitation: grant };
      if (Number(grant?.generation ?? 0) !== c.generation) return reject('access_revoked');
      if (grant && ['pending', 'accepted'].includes(String(grant.status)))
        return { schemaVersion: 1, kind: 'succeeded', invitation: grant };
      // Bind offline re-invite intents to the terminal status observed by the owner.
      if ((grant?.status ?? 'none') !== c.previousStatus) return reject('access_revoked');
      if (Object.keys(grants).length >= 32 && !grant) return reject('invite_limit');
      const targetAccount = (
        await tx.get(this.db.collection('identityAccounts').doc(target))
      ).data();
      if (targetAccount?.status !== 'active') return reject('target_unavailable');
      if (grant?.invitationId === c.invitationId) return reject('request_invalid');
      next = {
        planId: c.planId,
        ownerId: owner,
        inviteeId: target,
        invitationId: c.invitationId,
        generation: Number(c.generation) + 1,
        status: 'pending',
      };
    } else {
      if (!same) return reject('access_revoked');
      const required =
        c.commandType === 'accept' || c.commandType === 'decline' || c.commandType === 'cancel'
          ? 'pending'
          : 'accepted';
      if (safeTerminal || (c.commandType === 'accept' && grant?.status === 'accepted'))
        return { schemaVersion: 1, kind: 'succeeded', invitation: grant };
      if (grant?.status !== required) return reject('access_revoked');
      const statuses: Record<string, string> = {
        accept: 'accepted',
        decline: 'declined',
        cancel: 'cancelled',
        revoke: 'revoked',
        leave: 'left',
      };
      next = { ...grant, status: statuses[c.commandType] };
    }
    const result = { schemaVersion: 1, kind: 'succeeded', invitation: next };
    tx.update(ref, { invitations: { ...grants, [target]: next } });
    tx.create(receiptRef, { ownerId: actor, hash: hashCommand(c), result });
    return result;
  }
  async query(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    const r = record(raw);
    if (
      !r ||
      !exact(r, [
        'schemaVersion',
        'requestId',
        'planId',
        'queryType',
        'planOwnerId',
        'invitationId',
        'generation',
      ]) ||
      r.schemaVersion !== 1 ||
      !isEntityId(r.requestId) ||
      !((r.queryType === 'invitations' && r.planId === undefined) || isEntityId(r.planId)) ||
      (r.queryType !== undefined && r.queryType !== 'invitations') ||
      (r.planOwnerId !== undefined &&
        (!isEntityId(r.planOwnerId) ||
          !isEntityId(r.invitationId) ||
          !Number.isSafeInteger(r.generation) ||
          Number(r.generation) < 1)) ||
      (r.planOwnerId === undefined && (r.invitationId !== undefined || r.generation !== undefined))
    )
      return reject('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const owner = await this.owner(tx, hint);
      if (!owner) return reject('unauthenticated');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      if (r.queryType === 'invitations') {
        if (r.planId !== undefined || r.planOwnerId !== undefined) return reject('request_invalid');
        const received = await tx.get(
          this.db
            .collection(cols.plans)
            .where(new FieldPath('invitations', owner, 'inviteeId'), '==', owner),
        );
        const owned = await tx.get(this.db.collection(cols.plans).where('ownerId', '==', owner));
        const invitations: Record<string, unknown>[] = [];
        for (const doc of [...received.docs, ...owned.docs]) {
          const p = record(doc.data())!;
          if (p.status !== 'active') continue;
          const account = (
            await tx.get(this.db.collection('identityAccounts').doc(String(p.ownerId)))
          ).data();
          if (account?.status !== 'active') continue;
          for (const rawGrant of Object.values(record(p.invitations) ?? {})) {
            const g = record(rawGrant);
            if (g && (p.ownerId === owner || g.inviteeId === owner)) invitations.push(g);
          }
        }
        return { schemaVersion: 1, kind: 'succeeded', ownerId: owner, invitations };
      }
      const planOwner = typeof r.planOwnerId === 'string' ? r.planOwnerId : owner;
      const p = (
        await tx.get(this.db.collection(cols.plans).doc(planOwner + ':' + String(r.planId)))
      ).data() as Record<string, unknown> | undefined;
      if (planOwner !== owner) {
        const account = (
          await tx.get(this.db.collection('identityAccounts').doc(planOwner))
        ).data();
        const grants = p?.invitations as Record<string, Record<string, unknown>> | undefined;
        const grant = grants?.[owner];
        if (
          p?.status !== 'active' ||
          account?.status !== 'active' ||
          grant?.status !== 'accepted' ||
          grant.invitationId !== r.invitationId ||
          grant.generation !== r.generation
        )
          return reject('access_revoked');
      }
      // Allowlist: owner, receipts, session data and hashes never leave this service.
      const entry = p
        ? {
            planId: p.planId,
            revision: p.revision,
            status: p.status,
            updatedAtUtc: p.updatedAtUtc,
            ...(p.status === 'active' ? { plan: p.plan } : {}),
          }
        : null;
      return { schemaVersion: 1, kind: 'succeeded', ownerId: owner, entry };
    });
  }
}
