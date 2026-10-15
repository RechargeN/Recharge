import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import {
  assertContentEmulatorContext,
  contentCollections,
} from '../content/infrastructure/firestore_content_repository.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import { resolveContentType } from '../content/domain/content_type_registry.js';
import {
  commandHash,
  entryIdFor,
  exact,
  libraryCollections as cols,
  libraryFlagId,
  parseLibraryCommand,
  placeToday,
  record,
  rejected,
  type LibraryCommand,
  type LibraryEntry,
  type LibraryResult,
} from './library_contract.js';

const hash = (s: string) => createHash('sha256').update(s).digest('hex');
/** Emulator-only persistence. Actor is resolved from a verified session inside every transaction. */
export class FirestoreLibraryService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
  ) {
    assertContentEmulatorContext(db);
  }
  private async actor(tx: Transaction, hint: BookingAccessHint): Promise<string | null> {
    try {
      const decision = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      return decision.allowed ? decision.userId : null;
    } catch (error) {
      if (error instanceof TypeError) return null;
      throw error;
    }
  }
  private flag(tx: Transaction): Promise<boolean> {
    return new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(libraryFlagId, tx);
  }
  async command(hint: BookingAccessHint, raw: unknown): Promise<LibraryResult> {
    const command = parseLibraryCommand(raw);
    if (!command) return rejected('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const ownerId = await this.actor(tx, hint);
      if (!ownerId) return rejected('unauthenticated');
      if (command.ownerContext !== ownerId) return rejected('owner_changed');
      if (!(await this.flag(tx))) return rejected('feature_disabled');
      const ownerRef = this.db.collection(cols.owners).doc(ownerId);
      const owner = (await tx.get(ownerRef)).data();
      if (owner?.restricted === true || owner?.erased === true)
        return rejected('processing_restricted');
      const receiptRef = this.db
        .collection(cols.receipts)
        .doc(ownerId + ':' + hash(command.idempotencyKey));
      const receipt = (await tx.get(receiptRef)).data();
      if (receipt)
        return receipt.semanticHash === commandHash(command)
          ? (receipt.result as LibraryResult)
          : rejected('idempotency_conflict');
      const entryId = entryIdFor(command);
      const entryRef = this.db.collection(cols.entries).doc(ownerId + ':' + entryId);
      const existing = (await tx.get(entryRef)).data() as LibraryEntry | undefined;
      const currentRevision = existing?.revision ?? 0;
      const ownerRevision = Number(owner?.revision ?? 0);
      const nowUtc = this.clock.now().toISOString();
      const finish = (result: LibraryResult) => {
        tx.create(receiptRef, {
          schemaVersion: 1,
          ownerId,
          semanticHash: commandHash(command),
          result,
          recordedAtUtc: nowUtc,
        });
        return result;
      };
      if (currentRevision !== command.payload.expectedRevision)
        return finish(rejected('revision_conflict', { currentRevision, ownerRevision }));
      const removing =
        command.commandType === 'removeFavorite' || command.commandType === 'removeVisit';
      const status = removing ? 'removed' : 'active';
      if (existing?.status === status)
        return finish({ schemaVersion: 1, kind: 'succeeded', entry: existing, ownerRevision });
      let snapshot = existing?.snapshot ?? { title: '', city: '', category: '' };
      let timezoneId: string | null = existing?.timezoneId ?? null;
      if (!removing) {
        const target = await this.target(tx, command);
        if (!target) return finish(rejected('object_unavailable'));
        snapshot = target.snapshot;
        if (command.commandType === 'recordVisit') {
          timezoneId = target.timezoneId;
          if (!timezoneId) return finish(rejected('place_timezone_invalid'));
          try {
            if (command.payload.visitedOn! > placeToday(this.clock.now(), timezoneId))
              return finish(rejected('visit_date_future'));
          } catch {
            return finish(rejected('place_timezone_invalid'));
          }
        }
      }
      const entry: LibraryEntry = {
        schemaVersion: 1,
        entryId: existing?.entryId ?? command.payload.proposedEntryId,
        ownerId,
        snapshot,
        kind: command.commandType.endsWith('Favorite') ? 'favorite' : 'visit',
        objectId: command.payload.objectId,
        objectType: command.payload.objectType,
        visitedOn: command.payload.visitedOn ?? null,
        timezoneId,
        evidence: command.payload.visitedOn ? 'selfReported' : null,
        revision: currentRevision + 1,
        ownerRevision: ownerRevision + 1,
        status,
        updatedAtUtc: nowUtc,
      };
      tx.set(ownerRef, {
        schemaVersion: 1,
        revision: ownerRevision + 1,
        restricted: false,
        erased: false,
      });
      tx.set(entryRef, entry);
      return finish({
        schemaVersion: 1,
        kind: 'succeeded',
        entry,
        ownerRevision: ownerRevision + 1,
      });
    });
  }

  /** Source-owned public revision only; no drafts, client snapshots or title-based links. */
  private async target(
    tx: Transaction,
    command: LibraryCommand,
  ): Promise<{ timezoneId: string | null; snapshot: LibraryEntry['snapshot'] } | null> {
    const p = command.payload;
    const policy = resolveContentType(p.objectType);
    if (!policy || policy.visibilityPolicy !== 'public_catalog') return null;
    const pointer = (
      await tx.get(this.db.collection(contentCollections.pointers).doc(p.objectId))
    ).data();
    if (
      !pointer ||
      pointer.visibility !== 'visible' ||
      typeof pointer.currentPublishedRevisionId !== 'string'
    )
      return null;
    const revision = (
      await tx.get(
        this.db
          .collection(contentCollections.publishedRevisions)
          .doc(pointer.currentPublishedRevisionId),
      )
    ).data();
    const body = record(revision?.body);
    if (
      !revision ||
      !body ||
      revision.contentId !== p.objectId ||
      revision.typeId !== p.objectType ||
      revision.marketId !== 'LV' ||
      revision.bodyHash !== sha256Hex(canonicalJson(body)) ||
      (body.visibility !== undefined && body.visibility !== 'public')
    )
      return null;
    const location = record(body.location);
    return {
      snapshot: {
        title: typeof body.title === 'string' ? body.title : '',
        city:
          typeof location?.city === 'string'
            ? location.city
            : typeof body.city === 'string'
              ? body.city
              : '',
        category: typeof body.categoryId === 'string' ? body.categoryId : p.objectType,
      },
      timezoneId:
        typeof location?.timezoneId === 'string'
          ? location.timezoneId
          : typeof body.timezoneId === 'string'
            ? body.timezoneId
            : null,
    };
  }

  /** Latest-entry delta with tombstones. Revision pin prevents skipped records during paging. */
  async query(hint: BookingAccessHint, raw: unknown): Promise<LibraryResult> {
    const r = record(raw);
    if (
      !r ||
      !exact(r, [
        'schemaVersion',
        'requestId',
        'afterRevision',
        'expectedOwnerRevision',
        'limit',
      ]) ||
      r.schemaVersion !== 1 ||
      typeof r.requestId !== 'string' ||
      !Number.isSafeInteger(r.afterRevision) ||
      Number(r.afterRevision) < 0 ||
      !Number.isSafeInteger(r.limit) ||
      Number(r.limit) < 1 ||
      Number(r.limit) > 100 ||
      (r.expectedOwnerRevision !== undefined &&
        (!Number.isSafeInteger(r.expectedOwnerRevision) || Number(r.expectedOwnerRevision) < 0))
    )
      return rejected('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const ownerId = await this.actor(tx, hint);
      if (!ownerId) return rejected('unauthenticated');
      if (!(await this.flag(tx))) return rejected('feature_disabled');
      const owner = (await tx.get(this.db.collection(cols.owners).doc(ownerId))).data();
      if (owner?.restricted === true || owner?.erased === true)
        return rejected('processing_restricted');
      const revision = Number(owner?.revision ?? 0);
      if (r.expectedOwnerRevision !== undefined && r.expectedOwnerRevision !== revision)
        return rejected('snapshot_changed', { ownerRevision: revision });
      if (Number(r.afterRevision) > revision) return rejected('cursor_invalid');
      const snapshot = await tx.get(
        this.db
          .collection(cols.entries)
          .where('ownerId', '==', ownerId)
          .where('ownerRevision', '>', r.afterRevision)
          .orderBy('ownerRevision')
          .limit(Number(r.limit) + 1),
      );
      const entries = snapshot.docs.slice(0, Number(r.limit)).map((d) => d.data() as LibraryEntry);
      return {
        schemaVersion: 1,
        kind: 'succeeded',
        ownerId,
        ownerRevision: revision,
        entries,
        hasMore: snapshot.size > Number(r.limit),
        nextRevision: snapshot.size > Number(r.limit) ? entries.at(-1)!.ownerRevision : revision,
      };
    });
  }
}
