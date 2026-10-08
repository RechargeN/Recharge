import { createHash } from 'node:crypto';
import { Timestamp, type Firestore, type Transaction } from 'firebase-admin/firestore';

import { eventBookingDeliveryCollections } from '../../../booking/event_projection_delivery.js';
import { bookingCollections } from '../../../booking/transactions.js';
import { systemServerClock, type ServerClock } from '../../../shared/server_clock.js';
import {
  EventBookingHandoff,
  type BookingProjectionReader,
  type HandoffReceiptRecord,
  type HandoffRepository,
  type HandoffSource,
  type HandoffStatusRecord,
  type HandoffTransaction,
} from '../application/event_booking_handoff.js';
import type {
  EventBookingFactV1,
  HandoffContentState,
} from '../domain/event_internal_registration.js';
import { ContentPublicationFeed } from './content_publication_feed.js';
import {
  assertContentEmulatorContext,
  FirestoreContentRepository,
} from './firestore_content_repository.js';

/**
 * Handoff-owned collections (server-only, explicit deny in Rules). The outbox
 * is Booking's source collection, of which Event is the only writer (§35).
 */
export const eventBookingHandoffCollections = Object.freeze({
  status: 'eventBookingHandoffCheckpoints',
  receipts: 'eventBookingHandoffReceipts',
  states: 'eventBookingHandoffStates',
  outbox: eventBookingDeliveryCollections.sourceOutbox,
});

const statusId = 'content-effects-v1';

function receiptId(effectId: string): string {
  return createHash('sha256').update(effectId, 'utf8').digest('hex').slice(0, 40);
}

function plain<T>(value: T): Record<string, unknown> {
  return JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
}

class HandoffRepositoryConflict extends Error {
  constructor(readonly reason: 'receipt_exists') {
    super(reason);
    this.name = 'HandoffRepositoryConflict';
  }
}

/**
 * Emulator-only Firestore adapter of the handoff. Reads come first and writes
 * are buffered to commit time, so a refused or failed effect leaves nothing:
 * receipt, state, outbox records and checkpoint commit together or not at all.
 */
export class FirestoreEventBookingHandoffRepository implements HandoffRepository {
  constructor(
    private readonly firestore: Firestore,
    environment: NodeJS.ProcessEnv = process.env,
  ) {
    assertContentEmulatorContext(firestore, environment);
  }

  transact<T>(operation: (transaction: HandoffTransaction) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (transaction) => {
      const buffered = new BufferedHandoffTransaction(this.firestore, transaction);
      const result = await operation(buffered);
      await buffered.flush();
      return result;
    });
  }
}

class BufferedHandoffTransaction implements HandoffTransaction {
  #status: Record<string, unknown> | null = null;
  readonly #receipts = new Map<string, Record<string, unknown>>();
  readonly #states = new Map<string, Record<string, unknown>>();
  readonly #outbox = new Map<string, Record<string, unknown>>();

  constructor(
    private readonly firestore: Firestore,
    private readonly transaction: Transaction,
  ) {}

  private ref(collection: string, id: string) {
    return this.firestore.collection(collection).doc(id);
  }

  private async read<T>(collection: string, id: string): Promise<T | null> {
    const snapshot = await this.transaction.get(this.ref(collection, id));
    return snapshot.exists ? (snapshot.data() as T) : null;
  }

  async status(): Promise<HandoffStatusRecord | null> {
    if (this.#status !== null) return this.#status as unknown as HandoffStatusRecord;
    return this.read<HandoffStatusRecord>(eventBookingHandoffCollections.status, statusId);
  }

  putStatus(record: HandoffStatusRecord): void {
    this.#status = plain(record);
  }

  async receipt(effectId: string): Promise<HandoffReceiptRecord | null> {
    const buffered = this.#receipts.get(receiptId(effectId));
    if (buffered !== undefined) return buffered as unknown as HandoffReceiptRecord;
    return this.read<HandoffReceiptRecord>(
      eventBookingHandoffCollections.receipts,
      receiptId(effectId),
    );
  }

  putReceipt(record: HandoffReceiptRecord): void {
    const id = receiptId(record.effectId);
    if (this.#receipts.has(id)) throw new HandoffRepositoryConflict('receipt_exists');
    this.#receipts.set(id, plain(record));
  }

  async state(contentId: string): Promise<HandoffContentState | null> {
    const buffered = this.#states.get(contentId);
    if (buffered !== undefined) return buffered as unknown as HandoffContentState;
    return this.read<HandoffContentState>(eventBookingHandoffCollections.states, contentId);
  }

  putState(record: HandoffContentState): void {
    this.#states.set(record.contentId, plain(record));
  }

  async outboxExists(outboxId: string): Promise<boolean> {
    if (this.#outbox.has(outboxId)) return true;
    const snapshot = await this.transaction.get(
      this.ref(eventBookingHandoffCollections.outbox, outboxId),
    );
    return snapshot.exists;
  }

  createOutbox(outboxId: string, fact: EventBookingFactV1, createdAtUtc: string): void {
    if (this.#outbox.has(outboxId)) return;
    this.#outbox.set(outboxId, {
      schemaVersion: 1,
      outboxId,
      event: plain(fact),
      createdAtMs: Date.parse(createdAtUtc),
    });
  }

  /** Create-only receipts and outbox records; everything else is this run's own write. */
  async flush(): Promise<void> {
    for (const id of this.#receipts.keys()) {
      const snapshot = await this.transaction.get(
        this.ref(eventBookingHandoffCollections.receipts, id),
      );
      if (snapshot.exists) throw new HandoffRepositoryConflict('receipt_exists');
    }
    const fresh: [string, Record<string, unknown>][] = [];
    for (const [id, value] of this.#outbox) {
      const snapshot = await this.transaction.get(
        this.ref(eventBookingHandoffCollections.outbox, id),
      );
      // A deterministic id that already exists holds the same fact: keep it.
      if (!snapshot.exists) fresh.push([id, value]);
    }
    if (this.#status !== null)
      this.transaction.set(this.ref(eventBookingHandoffCollections.status, statusId), this.#status);
    for (const [id, value] of this.#receipts)
      this.transaction.create(this.ref(eventBookingHandoffCollections.receipts, id), value);
    for (const [id, value] of this.#states)
      this.transaction.set(this.ref(eventBookingHandoffCollections.states, id), value);
    for (const [id, value] of fresh) {
      const { createdAtMs, ...record } = value;
      this.transaction.create(this.ref(eventBookingHandoffCollections.outbox, id), {
        ...record,
        // Booking reads `createdAt` as a Firestore Timestamp.
        createdAt: Timestamp.fromMillis(createdAtMs as number),
      });
    }
  }
}

/** Read-only Booking view for reconciliation; it never writes Booking storage. */
export class FirestoreBookingProjectionReader implements BookingProjectionReader {
  constructor(private readonly firestore: Firestore) {}

  async projection(
    occurrenceId: string,
  ): Promise<{ readonly publicationRevision: number; readonly lifecycle: string } | null> {
    const snapshot = await this.firestore
      .collection(bookingCollections.eventProjections)
      .doc(occurrenceId)
      .get();
    if (!snapshot.exists) return null;
    return {
      publicationRevision: Number(snapshot.get('publicationRevision') ?? 0),
      lifecycle: String(snapshot.get('lifecycle')),
    };
  }

  async deadLetteredOutboxIds(prefix: string): Promise<readonly string[]> {
    const snapshot = await this.firestore
      .collection(eventBookingDeliveryCollections.deliveries)
      .where('status', '==', 'deadLetter')
      .get();
    return snapshot.docs.map((document) => document.id).filter((id) => id.startsWith(prefix));
  }
}

/** Composition of the Emulator-only handoff over the Content publication feed. */
export function createEmulatorEventBookingHandoff(
  firestore: Firestore,
  options: {
    readonly clock?: ServerClock;
    readonly environment?: NodeJS.ProcessEnv;
    /** Tests wrap the source to simulate a lost or failing read. */
    readonly source?: (source: HandoffSource) => HandoffSource;
  } = {},
) {
  const environment = options.environment ?? process.env;
  const feed = new ContentPublicationFeed(
    firestore,
    new FirestoreContentRepository(firestore, { environment }),
  );
  const base: HandoffSource = {
    effectsAfter: (after, limit) => feed.effectsAfter(after, limit),
    effectsForContent: (contentId, after, limit) => feed.effectsForContent(contentId, after, limit),
    async publishedRevision(publishedRevisionId) {
      const revision = await feed.publishedRevision(publishedRevisionId);
      return revision === null ? null : { typeId: revision.typeId, body: revision.body };
    },
    async pointersPage(afterContentId, limit) {
      const pointers = await feed.pointersPage(afterContentId, limit);
      return pointers.map((pointer) => ({
        contentId: pointer.contentId,
        revision: pointer.revision,
        currentPublishedRevisionId: pointer.currentPublishedRevisionId,
      }));
    },
  };
  const repository = new FirestoreEventBookingHandoffRepository(firestore, environment);
  const handoff = new EventBookingHandoff({
    repository,
    source: options.source === undefined ? base : options.source(base),
    booking: new FirestoreBookingProjectionReader(firestore),
    clock: options.clock ?? systemServerClock,
  });
  return Object.freeze({ repository, handoff });
}
