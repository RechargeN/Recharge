import { deepFreeze } from '../../../shared/immutable.js';
import { MediaRepositoryConflict } from '../domain/failures.js';
import type { MediaAsset } from '../domain/media_asset.js';
import type {
  MediaAuditEntry,
  MediaIdempotencyRecord,
  MediaRepository,
  MediaTransaction,
  StoredProcessingReceipt,
} from '../domain/repositories.js';
import type { UploadSession } from '../domain/upload_session.js';

interface Store {
  readonly assets: Map<string, MediaAsset>;
  readonly sessions: Map<string, UploadSession>;
  readonly receipts: Map<string, StoredProcessingReceipt>;
  readonly idempotency: Map<string, MediaIdempotencyRecord>;
  readonly audit: MediaAuditEntry[];
}

/**
 * Deterministic local adapter with serialized transactions. Writes are staged
 * and become visible only if the whole operation succeeds (all-or-nothing).
 * It is test infrastructure and carries no production authority.
 */
export class InMemoryMediaRepository implements MediaRepository {
  #store: Store = emptyStore();
  #tail: Promise<void> = Promise.resolve();

  async transact<T>(operation: (transaction: MediaTransaction) => T | Promise<T>): Promise<T> {
    let release: (() => void) | undefined;
    const previous = this.#tail;
    this.#tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    const working = cloneStore(this.#store);
    try {
      const result = await operation(transactionFor(working));
      this.#store = working;
      return result;
    } finally {
      release?.();
    }
  }

  /** Test-only inspection of committed state. */
  snapshot(): Readonly<{
    assets: readonly MediaAsset[];
    sessions: readonly UploadSession[];
    receipts: readonly StoredProcessingReceipt[];
    audit: readonly MediaAuditEntry[];
  }> {
    return deepFreeze({
      assets: [...this.#store.assets.values()],
      sessions: [...this.#store.sessions.values()],
      receipts: [...this.#store.receipts.values()],
      audit: [...this.#store.audit],
    });
  }
}

function emptyStore(): Store {
  return {
    assets: new Map(),
    sessions: new Map(),
    receipts: new Map(),
    idempotency: new Map(),
    audit: [],
  };
}

function cloneStore(store: Store): Store {
  // Stored values are deep-frozen and never mutated; copying containers suffices.
  return {
    assets: new Map(store.assets),
    sessions: new Map(store.sessions),
    receipts: new Map(store.receipts),
    idempotency: new Map(store.idempotency),
    audit: [...store.audit],
  };
}

function copy<T>(value: T): T {
  return deepFreeze(structuredClone(value)) as T;
}

function receiptKey(assetId: string, attemptNumber: number): string {
  return `${assetId}#${attemptNumber}`;
}

function idempotencyKey(actorUserId: string, commandType: string, key: string): string {
  return `${actorUserId.length}:${actorUserId}|${commandType}|${key}`;
}

function transactionFor(store: Store): MediaTransaction {
  return {
    asset: (assetId) => Promise.resolve(store.assets.get(assetId) ?? null),
    putAsset(asset, expectedStoredRevision) {
      const stored = store.assets.get(asset.assetId)?.revision ?? 0;
      if (stored !== expectedStoredRevision) throw new MediaRepositoryConflict('asset_revision');
      store.assets.set(asset.assetId, copy(asset));
    },
    session: (uploadSessionId) => Promise.resolve(store.sessions.get(uploadSessionId) ?? null),
    putSession(session, expectedStoredRevision) {
      const stored = store.sessions.get(session.uploadSessionId)?.revision ?? 0;
      if (stored !== expectedStoredRevision) throw new MediaRepositoryConflict('session_revision');
      store.sessions.set(session.uploadSessionId, copy(session));
    },
    receipt: (assetId, attemptNumber) =>
      Promise.resolve(store.receipts.get(receiptKey(assetId, attemptNumber)) ?? null),
    receiptsForAsset: (assetId) =>
      Promise.resolve(
        [...store.receipts.values()]
          .filter((item) => item.assetId === assetId)
          .sort((left, right) => left.attemptNumber - right.attemptNumber),
      ),
    putReceipt(receipt) {
      const key = receiptKey(receipt.assetId, receipt.attemptNumber);
      if (store.receipts.has(key)) throw new MediaRepositoryConflict('immutable_receipt');
      store.receipts.set(key, copy(receipt));
    },
    idempotency: (actorUserId, commandType, key) =>
      Promise.resolve(store.idempotency.get(idempotencyKey(actorUserId, commandType, key)) ?? null),
    putIdempotency(record) {
      store.idempotency.set(
        idempotencyKey(record.actorUserId, record.commandType, record.idempotencyKey),
        copy(record),
      );
    },
    appendAudit(entry) {
      store.audit.push(copy(entry));
    },
  };
}
