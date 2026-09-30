import type { ProcessingReceiptV1 } from '../../../contracts/media_v1.js';
import type { DeepReadonly } from '../../../shared/immutable.js';
import type { MediaAsset } from './media_asset.js';
import type { UploadSession } from './upload_session.js';

export interface MediaIdempotencyRecord {
  readonly actorUserId: string;
  readonly commandType: string;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly outcome: unknown;
  readonly createdAtUtc: string;
}

export interface MediaAuditEntry {
  readonly auditId: string;
  readonly occurredAtUtc: string;
  readonly actorUserId: string;
  readonly action: string;
  readonly subjectId: string;
  readonly outcome: 'succeeded';
}

export type StoredProcessingReceipt = DeepReadonly<ProcessingReceiptV1>;

export interface MediaTransaction {
  asset(assetId: string): Promise<MediaAsset | null>;
  /** Compare-and-set on the stored revision (0 = absent). */
  putAsset(asset: MediaAsset, expectedStoredRevision: number): void;
  session(uploadSessionId: string): Promise<UploadSession | null>;
  putSession(session: UploadSession, expectedStoredRevision: number): void;
  /** Receipts are immutable: an existing attempt is never overwritten. */
  receipt(assetId: string, attemptNumber: number): Promise<StoredProcessingReceipt | null>;
  receiptsForAsset(assetId: string): Promise<readonly StoredProcessingReceipt[]>;
  putReceipt(receipt: StoredProcessingReceipt): void;
  idempotency(
    actorUserId: string,
    commandType: string,
    idempotencyKey: string,
  ): Promise<MediaIdempotencyRecord | null>;
  putIdempotency(record: MediaIdempotencyRecord): void;
  appendAudit(entry: MediaAuditEntry): void;
}

/** The Media application service is the only caller allowed to write. */
export interface MediaRepository {
  transact<T>(operation: (transaction: MediaTransaction) => T | Promise<T>): Promise<T>;
}
