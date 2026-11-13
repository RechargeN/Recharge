import type {
  EnforcementReceipt,
  ModerationAuditEntry,
  ModerationDecision,
  PublisherTrustRecord,
} from './moderation.js';

export interface ModerationIdempotencyRecord {
  readonly actorUserId: string;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly decisionId: string;
}

export interface ModerationTransaction {
  decision(decisionId: string): Promise<ModerationDecision | null>;
  /** Create-only: a decision is never rewritten. */
  putDecision(decision: ModerationDecision): void;
  receipt(decisionId: string): Promise<EnforcementReceipt | null>;
  /** Create-only: a receipt is written once. */
  putReceipt(receipt: EnforcementReceipt): void;
  idempotency(
    actorUserId: string,
    idempotencyKey: string,
  ): Promise<ModerationIdempotencyRecord | null>;
  putIdempotency(record: ModerationIdempotencyRecord): void;
  appendAudit(entry: ModerationAuditEntry): void;
  /** RP-06: the publisher's current Route trust, if any decision set it. */
  publisherTrust(trustKey: string): Promise<PublisherTrustRecord | null>;
  /** RP-06: replaces the trust record (the caller keeps the newest decision). */
  putPublisherTrust(record: PublisherTrustRecord): void;
}

export interface ModerationRepository {
  transact<T>(operation: (transaction: ModerationTransaction) => T | Promise<T>): Promise<T>;
  /** Newest decisions first, with their receipts when enforcement was recorded. */
  recent(
    limit: number,
  ): Promise<readonly { decision: ModerationDecision; receipt: EnforcementReceipt | null }[]>;
}

export class ModerationRepositoryConflict extends Error {
  constructor(readonly reason: 'already_exists') {
    super(reason);
    this.name = 'ModerationRepositoryConflict';
  }
}
