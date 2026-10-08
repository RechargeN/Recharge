import { createHash } from 'node:crypto';
import { FieldPath, type Firestore, type Query, type Transaction } from 'firebase-admin/firestore';

import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';
import type {
  ActivePointerRecord,
  CatalogReportRecord,
  CatalogRepository,
  CatalogTransaction,
  FactReceiptRecord,
  ItemVersionRecord,
  ProjectionSetRecord,
  SourceStateRecord,
} from '../domain/repositories.js';

/** Derived, rebuildable read-side collections; clients get no access. */
export const catalogCollections = Object.freeze({
  sets: 'catalogProjectionSets',
  active: 'catalogActivePointer',
  versions: 'catalogItemVersions',
  states: 'catalogSourceStates',
  receipts: 'catalogFactReceipts',
  reports: 'catalogReports',
});

const activePointerId = 'current';

function plain<T>(value: T): Record<string, unknown> {
  return JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
}

function receiptId(setId: string, effectId: string): string {
  return `${setId}~${createHash('sha256').update(effectId, 'utf8').digest('hex').slice(0, 40)}`;
}

function stateId(setId: string, contentId: string): string {
  return `${setId}~${contentId}`;
}

class CatalogRepositoryConflict extends Error {
  constructor(readonly reason: 'receipt_exists') {
    super(reason);
    this.name = 'CatalogRepositoryConflict';
  }
}

/**
 * Emulator-only Firestore adapter of the Catalog. Reads come first, writes are
 * buffered and issued at commit, so a refused or failed fact leaves nothing
 * behind; a retried Firestore transaction re-runs the whole callback. Like
 * every local repository it refuses any context but the loopback
 * `demo-recharge` Emulator.
 */
export class FirestoreCatalogRepository implements CatalogRepository {
  constructor(
    private readonly firestore: Firestore,
    environment: NodeJS.ProcessEnv = process.env,
  ) {
    assertContentEmulatorContext(firestore, environment);
  }

  transact<T>(operation: (transaction: CatalogTransaction) => T | Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (transaction) => {
      const buffered = new BufferedCatalogTransaction(this.firestore, transaction);
      const result = await operation(buffered);
      await buffered.flush();
      return result;
    });
  }

  async versionsForSet(
    setId: string,
    marketId: string,
    typeId: string,
    limit: number,
  ): Promise<readonly ItemVersionRecord[]> {
    const snapshot = await this.firestore
      .collection(catalogCollections.versions)
      .where('setId', '==', setId)
      .where('marketId', '==', marketId)
      .where('typeId', '==', typeId)
      .limit(limit)
      .get();
    return snapshot.docs.map((document) => document.data() as ItemVersionRecord);
  }

  async versionsForContent(
    setId: string,
    contentId: string,
  ): Promise<readonly ItemVersionRecord[]> {
    const snapshot = await this.firestore
      .collection(catalogCollections.versions)
      .where('setId', '==', setId)
      .where('contentId', '==', contentId)
      .get();
    return snapshot.docs.map((document) => document.data() as ItemVersionRecord);
  }

  async sourceStates(
    setId: string,
    afterContentId: string | null,
    limit: number,
  ): Promise<readonly SourceStateRecord[]> {
    let query: Query = this.firestore
      .collection(catalogCollections.states)
      .where('setId', '==', setId)
      .orderBy(FieldPath.documentId(), 'asc');
    if (afterContentId !== null) query = query.startAfter(stateId(setId, afterContentId));
    const snapshot = await query.limit(limit).get();
    return snapshot.docs.map((document) => document.data() as SourceStateRecord);
  }

  async putReport(report: CatalogReportRecord): Promise<void> {
    await this.firestore
      .collection(catalogCollections.reports)
      .doc(report.reportId)
      .create(plain(report));
  }
}

class BufferedCatalogTransaction implements CatalogTransaction {
  readonly #sets = new Map<string, Record<string, unknown>>();
  readonly #states = new Map<string, Record<string, unknown>>();
  readonly #versions = new Map<string, Record<string, unknown>>();
  readonly #receipts = new Map<string, Record<string, unknown>>();
  #pointer: Record<string, unknown> | null = null;

  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
  ) {}

  private async read<T>(collection: string, id: string): Promise<T | null> {
    const snapshot = await this.transaction.get(this.firestore.collection(collection).doc(id));
    return snapshot.exists ? (snapshot.data() as T) : null;
  }

  async set(setId: string): Promise<ProjectionSetRecord | null> {
    const buffered = this.#sets.get(setId);
    if (buffered !== undefined) return buffered as unknown as ProjectionSetRecord;
    return this.read<ProjectionSetRecord>(catalogCollections.sets, setId);
  }

  putSet(record: ProjectionSetRecord): void {
    this.#sets.set(record.setId, plain(record));
  }

  async activePointer(): Promise<ActivePointerRecord | null> {
    if (this.#pointer !== null) return this.#pointer as unknown as ActivePointerRecord;
    return this.read<ActivePointerRecord>(catalogCollections.active, activePointerId);
  }

  putActivePointer(record: ActivePointerRecord): void {
    this.#pointer = plain(record);
  }

  async receipt(setId: string, effectId: string): Promise<FactReceiptRecord | null> {
    const id = receiptId(setId, effectId);
    const buffered = this.#receipts.get(id);
    if (buffered !== undefined) return buffered as unknown as FactReceiptRecord;
    return this.read<FactReceiptRecord>(catalogCollections.receipts, id);
  }

  putReceipt(record: FactReceiptRecord): void {
    const id = receiptId(record.setId, record.effectId);
    if (this.#receipts.has(id)) throw new CatalogRepositoryConflict('receipt_exists');
    this.#receipts.set(id, plain(record));
  }

  async sourceState(setId: string, contentId: string): Promise<SourceStateRecord | null> {
    const id = stateId(setId, contentId);
    const buffered = this.#states.get(id);
    if (buffered !== undefined) return buffered as unknown as SourceStateRecord;
    return this.read<SourceStateRecord>(catalogCollections.states, id);
  }

  putSourceState(record: SourceStateRecord): void {
    this.#states.set(stateId(record.setId, record.contentId), plain(record));
  }

  async itemVersion(versionId: string): Promise<ItemVersionRecord | null> {
    const buffered = this.#versions.get(versionId);
    if (buffered !== undefined) return buffered as unknown as ItemVersionRecord;
    return this.read<ItemVersionRecord>(catalogCollections.versions, versionId);
  }

  putItemVersion(record: ItemVersionRecord): void {
    this.#versions.set(record.versionId, plain(record));
  }

  /** Receipts are create-only; everything else is the transaction's own write. */
  async flush(): Promise<void> {
    for (const id of this.#receipts.keys()) {
      const snapshot = await this.transaction.get(
        this.firestore.collection(catalogCollections.receipts).doc(id),
      );
      if (snapshot.exists) throw new CatalogRepositoryConflict('receipt_exists');
    }
    for (const [id, value] of this.#sets)
      this.transaction.set(this.firestore.collection(catalogCollections.sets).doc(id), value);
    for (const [id, value] of this.#states)
      this.transaction.set(this.firestore.collection(catalogCollections.states).doc(id), value);
    for (const [id, value] of this.#versions)
      this.transaction.set(this.firestore.collection(catalogCollections.versions).doc(id), value);
    for (const [id, value] of this.#receipts)
      this.transaction.create(
        this.firestore.collection(catalogCollections.receipts).doc(id),
        value,
      );
    if (this.#pointer !== null)
      this.transaction.set(
        this.firestore.collection(catalogCollections.active).doc(activePointerId),
        this.#pointer,
      );
  }
}
