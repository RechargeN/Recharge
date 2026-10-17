import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import { assertContentEmulatorContext } from '../content/infrastructure/firestore_content_repository.js';
import { sha256Hex } from '../content/domain/published_revision.js';
import { exact, record } from '../library/library_contract.js';
import { isEntityId } from '../../shared/ids.js';
import {
  hashCommand,
  parseCommand,
  quickPlanCollections as cols,
  quickPlanFlag,
  reject,
  type Result,
} from './quick_plan_contract.js';

/** Emulator-only owner command path; no Content/Catalog/Scenario writes. */
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
      const ref = this.db.collection(cols.plans).doc(owner + ':' + c.planId);
      const receiptRef = this.db
        .collection(cols.receipts)
        .doc(owner + ':' + sha256Hex(c.idempotencyKey));
      const receipt = (await tx.get(receiptRef)).data();
      const current = (await tx.get(ref)).data();
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
      const entry = {
        planId: c.planId,
        revision: revision + 1,
        status: c.commandType === 'delete' ? 'deleted' : 'active',
        ...(c.commandType === 'delete' ? {} : { plan: c.plan }),
        updatedAtUtc: this.clock.now().toISOString(),
      };
      tx.set(ref, { ownerId: owner, ...entry });
      return finish({ schemaVersion: 1, kind: 'succeeded', entry });
    });
  }
  async query(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    const r = record(raw);
    if (
      !r ||
      !exact(r, ['schemaVersion', 'requestId', 'planId']) ||
      r.schemaVersion !== 1 ||
      !isEntityId(r.requestId) ||
      !isEntityId(r.planId)
    )
      return reject('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const owner = await this.owner(tx, hint);
      if (!owner) return reject('unauthenticated');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      const p = (
        await tx.get(this.db.collection(cols.plans).doc(owner + ':' + String(r.planId)))
      ).data() as Record<string, unknown> | undefined;
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
