import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';

import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';
import type {
  EnforcementReceipt,
  ModerationAuditEntry,
  ModerationDecision,
} from '../domain/moderation.js';
import {
  ModerationRepositoryConflict,
  type ModerationIdempotencyRecord,
  type ModerationRepository,
  type ModerationTransaction,
} from '../domain/repositories.js';

/** Server-owned collections; Firestore rules deny every client access. */
export const moderationCollections = Object.freeze({
  staffAuthority: 'moderationStaffAuthority',
  decisions: 'moderationDecisions',
  receipts: 'moderationEnforcementReceipts',
  idempotency: 'moderationIdempotency',
  audit: 'moderationAudit',
});

function plain<T>(value: T): Record<string, unknown> {
  return JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
}

function idempotencyId(actorUserId: string, key: string): string {
  return createHash('sha256')
    .update(`${actorUserId.length}:${actorUserId}|${key}`, 'utf8')
    .digest('hex');
}

/**
 * Emulator-only Firestore adapter. Decisions, receipts and audit entries are
 * create-only inside one transaction, so a decision or a receipt can never be
 * rewritten. Like the Content repository it refuses any context but the loopback
 * `demo-recharge` Emulator.
 */
export class FirestoreModerationRepository implements ModerationRepository {
  constructor(
    private readonly firestore: Firestore,
    environment: NodeJS.ProcessEnv = process.env,
  ) {
    assertContentEmulatorContext(firestore, environment);
  }

  transact<T>(operation: (transaction: ModerationTransaction) => T | Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (transaction) => {
      // A retried Firestore transaction re-runs this callback with a new buffer.
      const buffered = new BufferedModerationTransaction(this.firestore, transaction);
      const result = await operation(buffered);
      await buffered.flush();
      return result;
    });
  }

  async recent(limit: number) {
    const decisions = await this.firestore
      .collection(moderationCollections.decisions)
      .orderBy('decidedAtUtc', 'desc')
      .limit(limit)
      .get();
    const result = [];
    for (const document of decisions.docs) {
      const decision = document.data() as unknown as ModerationDecision;
      const receipt = await this.firestore
        .collection(moderationCollections.receipts)
        .doc(decision.decisionId)
        .get();
      result.push({
        decision,
        receipt: receipt.exists ? (receipt.data() as unknown as EnforcementReceipt) : null,
      });
    }
    return result;
  }
}

class BufferedModerationTransaction implements ModerationTransaction {
  readonly #decisions = new Map<string, Record<string, unknown>>();
  readonly #receipts = new Map<string, Record<string, unknown>>();
  readonly #idempotency = new Map<string, Record<string, unknown>>();
  readonly #audit: Record<string, unknown>[] = [];

  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
  ) {}

  private async read<T>(collection: string, id: string): Promise<T | null> {
    const snapshot = await this.transaction.get(this.firestore.collection(collection).doc(id));
    return snapshot.exists ? (snapshot.data() as T) : null;
  }

  async decision(decisionId: string): Promise<ModerationDecision | null> {
    const buffered = this.#decisions.get(decisionId);
    if (buffered !== undefined) return buffered as unknown as ModerationDecision;
    return this.read<ModerationDecision>(moderationCollections.decisions, decisionId);
  }

  putDecision(decision: ModerationDecision): void {
    if (this.#decisions.has(decision.decisionId))
      throw new ModerationRepositoryConflict('already_exists');
    this.#decisions.set(decision.decisionId, plain(decision));
  }

  async receipt(decisionId: string): Promise<EnforcementReceipt | null> {
    const buffered = this.#receipts.get(decisionId);
    if (buffered !== undefined) return buffered as unknown as EnforcementReceipt;
    return this.read<EnforcementReceipt>(moderationCollections.receipts, decisionId);
  }

  putReceipt(receipt: EnforcementReceipt): void {
    if (this.#receipts.has(receipt.decisionId))
      throw new ModerationRepositoryConflict('already_exists');
    this.#receipts.set(receipt.decisionId, plain(receipt));
  }

  async idempotency(
    actorUserId: string,
    idempotencyKey: string,
  ): Promise<ModerationIdempotencyRecord | null> {
    const id = idempotencyId(actorUserId, idempotencyKey);
    const buffered = this.#idempotency.get(id);
    if (buffered !== undefined) return buffered as unknown as ModerationIdempotencyRecord;
    return this.read<ModerationIdempotencyRecord>(moderationCollections.idempotency, id);
  }

  putIdempotency(record: ModerationIdempotencyRecord): void {
    this.#idempotency.set(idempotencyId(record.actorUserId, record.idempotencyKey), plain(record));
  }

  appendAudit(entry: ModerationAuditEntry): void {
    this.#audit.push(plain(entry));
  }

  /** Every create fails if the document exists; all reads happen before the first write. */
  async flush(): Promise<void> {
    const creates: Array<[string, string, Record<string, unknown>]> = [
      ...[...this.#decisions].map(
        ([id, value]) =>
          [moderationCollections.decisions, id, value] as [string, string, Record<string, unknown>],
      ),
      ...[...this.#receipts].map(
        ([id, value]) =>
          [moderationCollections.receipts, id, value] as [string, string, Record<string, unknown>],
      ),
      ...[...this.#idempotency].map(
        ([id, value]) =>
          [moderationCollections.idempotency, id, value] as [
            string,
            string,
            Record<string, unknown>,
          ],
      ),
      ...this.#audit.map(
        (entry) =>
          [moderationCollections.audit, String(entry.auditId), entry] as [
            string,
            string,
            Record<string, unknown>,
          ],
      ),
    ];
    for (const [collection, id] of creates) {
      const snapshot = await this.transaction.get(this.firestore.collection(collection).doc(id));
      if (snapshot.exists) throw new ModerationRepositoryConflict('already_exists');
    }
    for (const [collection, id, value] of creates) {
      this.transaction.create(this.firestore.collection(collection).doc(id), value);
    }
  }
}
