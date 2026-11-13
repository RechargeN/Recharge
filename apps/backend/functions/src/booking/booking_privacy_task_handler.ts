import type { BookingRecord } from './domain.js';
import { pseudonymizeBookingIdentity, type BookingIdentityBearingRecord } from './privacy.js';

export type BookingPrivacyTaskType = 'access' | 'erasure' | 'restriction';

export type BookingPrivacyTaskResult =
  | Readonly<{
      kind: 'succeeded';
      evidence: Readonly<{
        recordCount: number;
        pseudonymizedCount: number;
        retainedCount: number;
        outcome: 'completed' | 'retained_legal_hold';
      }>;
    }>
  | Readonly<{
      kind: 'retryableFailure';
      code: 'active_future_booking_cancellation_required' | 'temporarily_unavailable';
    }>
  | Readonly<{ kind: 'failed'; code: 'invalid_task' | 'invalid_record' }>;

export interface BookingPrivacyRecordStore {
  runAtomic<T>(operation: (records: BookingIdentityBearingRecord[]) => T): Promise<T>;
  runPagedErasure?(input: {
    readonly pseudonymousActorId: string;
    readonly nowUtc: string;
  }): Promise<
    Readonly<{
      recordCount: number;
      pseudonymizedCount: number;
      activeFutureBookingCount: number;
      legalHoldCount: number;
    }>
  >;
}

export class InMemoryBookingPrivacyRecordStore implements BookingPrivacyRecordStore {
  readonly #records: BookingIdentityBearingRecord[];

  constructor(records: readonly BookingIdentityBearingRecord[]) {
    this.#records = records.map((record) => ({ ...record }));
  }

  runAtomic<T>(operation: (records: BookingIdentityBearingRecord[]) => T): Promise<T> {
    const working = this.#records.map((record) => ({ ...record }));
    const result = operation(working);
    this.#records.splice(0, this.#records.length, ...working);
    return Promise.resolve(result);
  }

  snapshot(): readonly BookingIdentityBearingRecord[] {
    return Object.freeze(this.#records.map((record) => Object.freeze({ ...record })));
  }
}

export class BookingPrivacyTaskHandler {
  constructor(private readonly store: BookingPrivacyRecordStore) {}

  async handle(input: {
    readonly taskType: BookingPrivacyTaskType;
    readonly subjectId: string;
    readonly pseudonymousActorId?: string;
    readonly nowUtc: string;
  }): Promise<BookingPrivacyTaskResult> {
    try {
      if (!Number.isFinite(Date.parse(input.nowUtc)) || input.subjectId.trim().length === 0) {
        return { kind: 'failed', code: 'invalid_task' };
      }
      if (
        input.taskType === 'erasure' &&
        input.pseudonymousActorId !== undefined &&
        this.store.runPagedErasure !== undefined
      ) {
        const evidence = await this.store.runPagedErasure({
          pseudonymousActorId: input.pseudonymousActorId,
          nowUtc: input.nowUtc,
        });
        if (evidence.activeFutureBookingCount > 0) {
          return {
            kind: 'retryableFailure',
            code: 'active_future_booking_cancellation_required',
          };
        }
        return {
          kind: 'succeeded',
          evidence: {
            recordCount: evidence.recordCount,
            pseudonymizedCount: evidence.pseudonymizedCount,
            retainedCount: evidence.legalHoldCount,
            outcome: evidence.legalHoldCount > 0 ? 'retained_legal_hold' : 'completed',
          },
        };
      }
      return await this.store.runAtomic((records) => {
        const indexes = records
          .map((record, index) => ({ record, index }))
          .filter(({ record }) => actorId(record) === input.subjectId);
        if (input.taskType === 'access' || input.taskType === 'restriction') {
          return {
            kind: 'succeeded',
            evidence: {
              recordCount: indexes.length,
              pseudonymizedCount: 0,
              retainedCount: 0,
              outcome: 'completed',
            },
          } as const;
        }
        if (input.pseudonymousActorId === undefined) {
          return { kind: 'failed', code: 'invalid_task' } as const;
        }
        const hasActiveFutureBooking = indexes.some(({ record }) =>
          isActiveFutureBooking(record, input.nowUtc),
        );
        if (hasActiveFutureBooking) {
          return {
            kind: 'retryableFailure',
            code: 'active_future_booking_cancellation_required',
          } as const;
        }
        const retained = indexes.filter(({ record }) => hasLegalHold(record));
        for (const { record, index } of indexes) {
          if (hasLegalHold(record)) continue;
          records[index] = pseudonymizeBookingIdentity(record, input.pseudonymousActorId);
        }
        return {
          kind: 'succeeded',
          evidence: {
            recordCount: indexes.length,
            pseudonymizedCount: indexes.length - retained.length,
            retainedCount: retained.length,
            outcome: retained.length > 0 ? 'retained_legal_hold' : 'completed',
          },
        } as const;
      });
    } catch (error) {
      return error instanceof TypeError
        ? { kind: 'failed', code: 'invalid_record' }
        : { kind: 'retryableFailure', code: 'temporarily_unavailable' };
    }
  }
}

function hasLegalHold(record: BookingIdentityBearingRecord): boolean {
  return record.legalHold === true;
}

function actorId(record: BookingIdentityBearingRecord): string {
  return 'userId' in record ? record.userId : record.actorId;
}

function isActiveFutureBooking(
  record: BookingIdentityBearingRecord,
  nowUtc: string,
): record is BookingRecord {
  return (
    'userId' in record &&
    record.state === 'confirmed' &&
    (!('occurrenceEndSnapshot' in record) ||
      typeof record.occurrenceEndSnapshot !== 'string' ||
      Date.parse(record.occurrenceEndSnapshot) > Date.parse(nowUtc))
  );
}
