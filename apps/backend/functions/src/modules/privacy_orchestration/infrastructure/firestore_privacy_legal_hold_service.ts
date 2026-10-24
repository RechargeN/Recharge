import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';
import {
  changePrivacyLegalHold,
  placePrivacyLegalHold,
  releasePrivacyLegalHold,
  type PrivacyLegalHold,
  type PrivacyLegalHoldScope,
} from '../domain/privacy_legal_hold.js';

export const privacyHoldCollections = Object.freeze({
  holds: 'privacyLegalHolds',
  audit: 'privacyLegalHoldAudit',
  /** Emulator test registry of hold authorities; production authority is PB-06. */
  authority: 'privacyHoldAuthority',
});

export type PrivacyHoldResult =
  | { readonly ok: true; readonly hold: PrivacyLegalHold }
  | {
      readonly ok: false;
      readonly code:
        | 'authority_denied'
        | 'invalid_contract'
        | 'hold_id_conflict'
        | 'not_found'
        | 'revision_conflict'
        | 'not_active';
    };

/**
 * L1 legal hold authority (amendment §7). Only an actor registered in the
 * server-side authority registry may place, change or release a hold; there
 * is no client entry. Every change is revisioned and audited without its basis.
 * Emulator-only, like the registry it reads.
 */
export class FirestorePrivacyLegalHoldService {
  constructor(private readonly db: Firestore) {
    assertContentEmulatorContext(db);
  }

  place(input: {
    readonly actorId: string;
    readonly holdId: string;
    readonly subjectId: string;
    readonly scope: PrivacyLegalHoldScope;
    readonly basisRef: string;
    readonly reviewAtUtc: string;
    readonly nowUtc: string;
  }): Promise<PrivacyHoldResult> {
    let next: PrivacyLegalHold;
    try {
      next = placePrivacyLegalHold({ ...input, placedBy: input.actorId });
    } catch {
      return Promise.resolve({ ok: false, code: 'invalid_contract' });
    }
    return this.db.runTransaction(async (tx) => {
      if (!(await this.authorized(tx, input.actorId))) return deny();
      const ref = this.ref(next.holdId);
      const current = (await tx.get(ref)).data() as PrivacyLegalHold | undefined;
      if (current !== undefined) {
        // A repeated placement of the same hold answers with the stored one.
        return current.subjectId === next.subjectId &&
          current.basisRef === next.basisRef &&
          sameScope(current.scope, next.scope)
          ? { ok: true, hold: current }
          : { ok: false, code: 'hold_id_conflict' };
      }
      tx.create(ref, next);
      this.audit(tx, next, 'placed', input.actorId, input.nowUtc);
      return { ok: true, hold: next };
    });
  }

  change(input: {
    readonly actorId: string;
    readonly holdId: string;
    readonly expectedRevision: number;
    readonly scope?: PrivacyLegalHoldScope;
    readonly reviewAtUtc?: string;
    readonly nowUtc: string;
  }): Promise<PrivacyHoldResult> {
    return this.update(input, 'changed', (hold) =>
      changePrivacyLegalHold({
        hold,
        nowUtc: input.nowUtc,
        ...(input.scope === undefined ? {} : { scope: input.scope }),
        ...(input.reviewAtUtc === undefined ? {} : { reviewAtUtc: input.reviewAtUtc }),
      }),
    );
  }

  release(input: {
    readonly actorId: string;
    readonly holdId: string;
    readonly expectedRevision: number;
    readonly nowUtc: string;
  }): Promise<PrivacyHoldResult> {
    return this.update(input, 'released', (hold) =>
      releasePrivacyLegalHold({ hold, nowUtc: input.nowUtc }),
    );
  }

  /**
   * Active holds of one subject. Read inside the caller's transaction, the hold
   * query joins its read set: a hold placed concurrently aborts and retries it.
   */
  async activeHolds(subjectId: string, tx?: Transaction): Promise<readonly PrivacyLegalHold[]> {
    const query = this.db
      .collection(privacyHoldCollections.holds)
      .where('subjectId', '==', subjectId)
      .where('status', '==', 'active');
    const snapshot = tx === undefined ? await query.get() : await tx.get(query);
    return snapshot.docs.map((document) => document.data() as PrivacyLegalHold);
  }

  private update(
    input: {
      readonly actorId: string;
      readonly holdId: string;
      readonly expectedRevision: number;
      readonly nowUtc: string;
    },
    action: 'changed' | 'released',
    transition: (hold: PrivacyLegalHold) => PrivacyLegalHold,
  ): Promise<PrivacyHoldResult> {
    return this.db.runTransaction(async (tx) => {
      if (!(await this.authorized(tx, input.actorId))) return deny();
      const ref = this.ref(input.holdId);
      const current = (await tx.get(ref)).data() as PrivacyLegalHold | undefined;
      if (current === undefined) return { ok: false, code: 'not_found' } as const;
      if (current.revision !== input.expectedRevision)
        return { ok: false, code: 'revision_conflict' } as const;
      if (current.status !== 'active') return { ok: false, code: 'not_active' } as const;
      let next: PrivacyLegalHold;
      try {
        next = transition(current);
      } catch {
        return { ok: false, code: 'invalid_contract' } as const;
      }
      tx.set(ref, next);
      this.audit(tx, next, action, input.actorId, input.nowUtc);
      return { ok: true, hold: next } as const;
    });
  }

  private async authorized(tx: Transaction, actorId: string): Promise<boolean> {
    if (!/^[A-Za-z0-9:._-]{1,128}$/.test(actorId)) return false;
    const authority = (
      await tx.get(this.db.collection(privacyHoldCollections.authority).doc(actorId))
    ).data();
    return authority?.active === true;
  }

  private audit(
    tx: Transaction,
    hold: PrivacyLegalHold,
    action: 'placed' | 'changed' | 'released',
    actorId: string,
    atUtc: string,
  ): void {
    // The basis stays on the hold record only; the audit names who and when.
    tx.create(
      this.db.collection(privacyHoldCollections.audit).doc(`${hold.holdId}:${hold.revision}`),
      {
        holdId: hold.holdId,
        revision: hold.revision,
        action,
        actorId,
        atUtc,
      },
    );
  }

  private ref(holdId: string) {
    return this.db.collection(privacyHoldCollections.holds).doc(holdId);
  }
}

function deny(): PrivacyHoldResult {
  return { ok: false, code: 'authority_denied' };
}

function sameScope(left: PrivacyLegalHoldScope, right: PrivacyLegalHoldScope): boolean {
  return (
    left.domainId === right.domainId &&
    left.collection === right.collection &&
    left.recordId === right.recordId
  );
}
