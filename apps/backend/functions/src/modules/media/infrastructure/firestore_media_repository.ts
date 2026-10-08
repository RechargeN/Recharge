import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';

import type { MediaEffectV1 } from '../../../contracts/media_v1.js';
import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';
import { MediaRepositoryConflict } from '../domain/failures.js';
import type { MediaAsset } from '../domain/media_asset.js';
import type {
  MediaAuditEntry,
  MediaIdempotencyRecord,
  MediaRepository,
  MediaTransaction,
  StoredDeletionStatus,
  StoredProcessingReceipt,
} from '../domain/repositories.js';
import type { UploadSession } from '../domain/upload_session.js';

export const mediaCollections = Object.freeze({
  assets: 'mediaAssets',
  sessions: 'mediaUploadSessions',
  receipts: 'mediaProcessingReceipts',
  deletions: 'mediaDeletionStatuses',
  idempotency: 'mediaIdempotency',
  audit: 'mediaAudit',
  effects: 'mediaEffects',
});

type Kind = 'asset' | 'session' | 'deletion';

interface BufferedCas {
  readonly kind: Kind;
  readonly id: string;
  readonly expected: number;
  readonly value: Record<string, unknown>;
  readonly nextRevision: number;
}

/**
 * Emulator-only Firestore adapter of the Media repository. Writes are buffered
 * and verified (compare-and-set on stored revisions, immutable receipts) inside
 * the one Firestore transaction that applies them, so a failed command leaves
 * nothing behind. Like the Content repository it refuses any context but the
 * loopback `demo-recharge` Emulator.
 */
export class FirestoreMediaRepository implements MediaRepository {
  constructor(
    private readonly firestore: Firestore,
    environment: NodeJS.ProcessEnv = process.env,
  ) {
    assertContentEmulatorContext(firestore, environment);
  }

  transact<T>(operation: (transaction: MediaTransaction) => T | Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (transaction) => {
      // A retried Firestore transaction re-runs this callback with a new buffer.
      const buffered = new BufferedMediaTransaction(this.firestore, transaction);
      const result = await operation(buffered);
      await buffered.flush();
      return result;
    });
  }
}

/** Firestore stores plain JSON: drop `undefined` and detach frozen objects. */
function plain<T>(value: T): Record<string, unknown> {
  return JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
}

function receiptId(assetId: string, attemptNumber: number): string {
  return `${assetId}__${attemptNumber}`;
}

function idempotencyId(actorUserId: string, commandType: string, key: string): string {
  return createHash('sha256')
    .update(`${actorUserId.length}:${actorUserId}|${commandType}|${key}`, 'utf8')
    .digest('hex');
}

class BufferedMediaTransaction implements MediaTransaction {
  readonly #cas: BufferedCas[] = [];
  readonly #overlay = new Map<string, Record<string, unknown>>();
  readonly #receipts = new Map<string, Record<string, unknown>>();
  readonly #idempotency = new Map<string, Record<string, unknown>>();
  readonly #audit: Record<string, unknown>[] = [];
  readonly #effects: Record<string, unknown>[] = [];

  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
  ) {}

  readonly effects = {
    append: (effect: MediaEffectV1): void => {
      this.#effects.push(plain(effect));
    },
  };

  private collectionOf(kind: Kind): string {
    return kind === 'asset'
      ? mediaCollections.assets
      : kind === 'session'
        ? mediaCollections.sessions
        : mediaCollections.deletions;
  }

  private async read<T>(kind: Kind, id: string): Promise<T | null> {
    const buffered = this.#overlay.get(`${kind}:${id}`);
    if (buffered !== undefined) return buffered as T;
    const snapshot = await this.transaction.get(
      this.firestore.collection(this.collectionOf(kind)).doc(id),
    );
    return snapshot.exists ? (snapshot.data() as T) : null;
  }

  private buffer(kind: Kind, id: string, expected: number, value: unknown, revision: number) {
    const stored = plain(value);
    this.#overlay.set(`${kind}:${id}`, stored);
    this.#cas.push({ kind, id, expected, value: stored, nextRevision: revision });
  }

  asset(assetId: string): Promise<MediaAsset | null> {
    return this.read<MediaAsset>('asset', assetId);
  }

  putAsset(asset: MediaAsset, expectedStoredRevision: number): void {
    this.buffer('asset', asset.assetId, expectedStoredRevision, asset, asset.revision);
  }

  session(uploadSessionId: string): Promise<UploadSession | null> {
    return this.read<UploadSession>('session', uploadSessionId);
  }

  async sessionForAsset(assetId: string): Promise<UploadSession | null> {
    for (const [key, value] of this.#overlay) {
      if (key.startsWith('session:') && value.assetId === assetId) return value as UploadSession;
    }
    const snapshot = await this.transaction.get(
      this.firestore.collection(mediaCollections.sessions).where('assetId', '==', assetId).limit(1),
    );
    return (snapshot.docs[0]?.data() as UploadSession | undefined) ?? null;
  }

  putSession(session: UploadSession, expectedStoredRevision: number): void {
    this.buffer(
      'session',
      session.uploadSessionId,
      expectedStoredRevision,
      session,
      session.revision,
    );
  }

  async receipt(assetId: string, attemptNumber: number): Promise<StoredProcessingReceipt | null> {
    const id = receiptId(assetId, attemptNumber);
    const buffered = this.#receipts.get(id);
    if (buffered !== undefined) return buffered as unknown as StoredProcessingReceipt;
    const snapshot = await this.transaction.get(
      this.firestore.collection(mediaCollections.receipts).doc(id),
    );
    return snapshot.exists ? (snapshot.data() as unknown as StoredProcessingReceipt) : null;
  }

  async receiptsForAsset(assetId: string): Promise<readonly StoredProcessingReceipt[]> {
    const snapshot = await this.transaction.get(
      this.firestore.collection(mediaCollections.receipts).where('assetId', '==', assetId),
    );
    const byId = new Map<string, StoredProcessingReceipt>();
    for (const document of snapshot.docs) {
      byId.set(document.id, document.data() as unknown as StoredProcessingReceipt);
    }
    for (const [id, value] of this.#receipts) {
      if (value.assetId === assetId) byId.set(id, value as unknown as StoredProcessingReceipt);
    }
    return [...byId.values()].sort((left, right) => left.attemptNumber - right.attemptNumber);
  }

  putReceipt(receipt: StoredProcessingReceipt): void {
    const id = receiptId(receipt.assetId, receipt.attemptNumber);
    if (this.#receipts.has(id)) throw new MediaRepositoryConflict('immutable_receipt');
    this.#receipts.set(id, plain(receipt));
  }

  deletion(assetId: string): Promise<StoredDeletionStatus | null> {
    return this.read<StoredDeletionStatus>('deletion', assetId);
  }

  putDeletion(status: StoredDeletionStatus, expectedStoredRevision: number): void {
    this.buffer(
      'deletion',
      status.assetId,
      expectedStoredRevision,
      status,
      status.deletionRevision,
    );
  }

  async idempotency(
    actorUserId: string,
    commandType: string,
    idempotencyKey: string,
  ): Promise<MediaIdempotencyRecord | null> {
    const id = idempotencyId(actorUserId, commandType, idempotencyKey);
    const buffered = this.#idempotency.get(id);
    if (buffered !== undefined) return buffered as unknown as MediaIdempotencyRecord;
    const snapshot = await this.transaction.get(
      this.firestore.collection(mediaCollections.idempotency).doc(id),
    );
    return snapshot.exists ? (snapshot.data() as unknown as MediaIdempotencyRecord) : null;
  }

  putIdempotency(record: MediaIdempotencyRecord): void {
    this.#idempotency.set(
      idempotencyId(record.actorUserId, record.commandType, record.idempotencyKey),
      plain(record),
    );
  }

  appendAudit(entry: MediaAuditEntry): void {
    this.#audit.push(plain(entry));
  }

  /** Verifies every compare-and-set against stored state, then writes. */
  async flush(): Promise<void> {
    // All reads first (Firestore forbids a read after a write in one transaction).
    const stored = new Map<string, number>();
    for (const item of this.#cas) {
      const key = `${item.kind}:${item.id}`;
      if (stored.has(key)) continue;
      const snapshot = await this.transaction.get(
        this.firestore.collection(this.collectionOf(item.kind)).doc(item.id),
      );
      const revisionField = item.kind === 'deletion' ? 'deletionRevision' : 'revision';
      const revision = snapshot.exists ? Number(snapshot.get(revisionField)) : 0;
      stored.set(key, revision);
    }
    for (const [id, value] of this.#receipts) {
      const snapshot = await this.transaction.get(
        this.firestore.collection(mediaCollections.receipts).doc(id),
      );
      if (snapshot.exists) throw new MediaRepositoryConflict('immutable_receipt');
      void value;
    }
    // Replay the compare-and-set chain in order against the stored revisions.
    const current = new Map(stored);
    for (const item of this.#cas) {
      const key = `${item.kind}:${item.id}`;
      if (current.get(key) !== item.expected) {
        throw new MediaRepositoryConflict(
          item.kind === 'session' ? 'session_revision' : 'asset_revision',
        );
      }
      current.set(key, item.nextRevision);
    }
    const last = new Map<string, BufferedCas>();
    for (const item of this.#cas) last.set(`${item.kind}:${item.id}`, item);
    for (const item of last.values()) {
      this.transaction.set(
        this.firestore.collection(this.collectionOf(item.kind)).doc(item.id),
        item.value,
      );
    }
    for (const [id, value] of this.#receipts) {
      this.transaction.create(this.firestore.collection(mediaCollections.receipts).doc(id), value);
    }
    for (const [id, value] of this.#idempotency) {
      this.transaction.set(this.firestore.collection(mediaCollections.idempotency).doc(id), value);
    }
    for (const entry of this.#audit) {
      this.transaction.set(
        this.firestore.collection(mediaCollections.audit).doc(String(entry.auditId)),
        entry,
      );
    }
    for (const effect of this.#effects) {
      this.transaction.set(
        this.firestore.collection(mediaCollections.effects).doc(String(effect.effectId)),
        effect,
      );
    }
  }
}
