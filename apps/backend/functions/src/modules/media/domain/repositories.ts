import type {
  MediaDeletionStatusV1,
  MediaFamily,
  ProcessingReceiptV1,
} from '../../../contracts/media_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import type { MediaEffectSink } from '../application/ports/media_effect_sink.js';
import type { DeepReadonly } from '../../../shared/immutable.js';
import type { MediaAsset } from './media_asset.js';
import type { UploadSession } from './upload_session.js';

/** One authority check a stored command result relied on; repeated on every replay. */
export interface MediaAuthorization {
  readonly marketId: MarketId;
  readonly publisherRef?: PublisherRefV1;
  readonly family: MediaFamily;
  readonly action: 'upload' | 'read' | 'manage';
}

export interface MediaIdempotencyRecord {
  readonly actorUserId: string;
  readonly commandType: string;
  readonly idempotencyKey: string;
  readonly semanticHash: string;
  readonly outcome: unknown;
  /** Empty only for system instructions, which carry their own verified authority. */
  readonly authorizations: readonly MediaAuthorization[];
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
export type StoredDeletionStatus = DeepReadonly<MediaDeletionStatusV1>;

export interface MediaTransaction {
  asset(assetId: string): Promise<MediaAsset | null>;
  /** Compare-and-set on the stored revision (0 = absent). */
  putAsset(asset: MediaAsset, expectedStoredRevision: number): void;
  session(uploadSessionId: string): Promise<UploadSession | null>;
  sessionForAsset(assetId: string): Promise<UploadSession | null>;
  putSession(session: UploadSession, expectedStoredRevision: number): void;
  /** Receipts are immutable: an existing attempt is never overwritten. */
  receipt(assetId: string, attemptNumber: number): Promise<StoredProcessingReceipt | null>;
  receiptsForAsset(assetId: string): Promise<readonly StoredProcessingReceipt[]>;
  putReceipt(receipt: StoredProcessingReceipt): void;
  deletion(assetId: string): Promise<StoredDeletionStatus | null>;
  /** Compare-and-set on the stored deletion revision (0 = absent). */
  putDeletion(status: StoredDeletionStatus, expectedStoredRevision: number): void;
  idempotency(
    actorUserId: string,
    commandType: string,
    idempotencyKey: string,
  ): Promise<MediaIdempotencyRecord | null>;
  putIdempotency(record: MediaIdempotencyRecord): void;
  appendAudit(entry: MediaAuditEntry): void;
  readonly effects: MediaEffectSink;
}

/** The Media application service is the only caller allowed to write. */
export interface MediaRepository {
  transact<T>(operation: (transaction: MediaTransaction) => T | Promise<T>): Promise<T>;
}
