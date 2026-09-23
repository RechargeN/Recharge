import type { Firestore } from 'firebase-admin/firestore';
import type { GetEventAvailabilityQuery } from '../contracts/booking_v1.js';
import { type PoolLedger } from '../inventory/ledger.js';
import {
  BookingDomainRefusal,
  rejected,
  succeeded,
  type BookingResult,
} from '../shared/failures.js';
import {
  classifyFirestoreFailure,
  type FirestoreFailureLogger,
} from '../shared/firestore_failure.js';
import type { ServerClock } from '../shared/server_clock.js';
import { assertBookingEventProjection } from './domain.js';
import { bookingCollections, finitePoolLedgerId } from './transactions.js';

export interface EventAvailability {
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly capacityMode: 'finite' | 'unlimited' | 'notApplicable';
  readonly channel?: 'onsite' | 'online' | 'any';
  readonly asOf: string;
  readonly eventRevision: number;
  readonly status: 'notOpen' | 'available' | 'limited' | 'soldOut' | 'closed';
  readonly authority: 'authoritative';
  readonly ledgerRevision?: number;
  readonly availableUnits?: number;
  readonly registrationOpensAt?: string;
  readonly registrationClosesAt?: string;
}

export async function getEventAvailability(
  firestore: Firestore,
  clock: ServerClock,
  query: GetEventAvailabilityQuery,
  failureLogger?: FirestoreFailureLogger,
): Promise<BookingResult<EventAvailability>> {
  try {
    const now = clock.now();
    const nowIso = now.toISOString();
    const eventSnapshot = await firestore
      .collection(bookingCollections.eventProjections)
      .doc(query.payload.occurrenceId)
      .get();
    const raw = eventSnapshot.data();
    const rawPoolId = typeof raw?.poolId === 'string' ? raw.poolId : undefined;
    const event = assertBookingEventProjection(
      raw,
      query.payload.occurrenceId,
      rawPoolId,
      query.payload.channel,
    );
    if (event.eventId !== query.payload.eventId) return rejected('event_unavailable');
    if (
      event.registrationWindow.opensAt !== undefined &&
      now < new Date(event.registrationWindow.opensAt)
    ) {
      return succeeded({
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        capacityMode: 'notApplicable',
        ...(event.channel === undefined ? {} : { channel: event.channel }),
        asOf: nowIso,
        eventRevision: event.materialRevision,
        status: 'notOpen',
        authority: 'authoritative',
        registrationOpensAt: event.registrationWindow.opensAt,
      });
    }
    if (
      event.registrationWindow.closesAt !== undefined &&
      now >= new Date(event.registrationWindow.closesAt)
    ) {
      return succeeded({
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        capacityMode: 'notApplicable',
        ...(event.channel === undefined ? {} : { channel: event.channel }),
        asOf: nowIso,
        eventRevision: event.materialRevision,
        status: 'closed',
        authority: 'authoritative',
        registrationClosesAt: event.registrationWindow.closesAt,
      });
    }
    if (event.capacityMode === 'unlimited') {
      return succeeded({
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        capacityMode: 'unlimited',
        ...(event.channel === undefined ? {} : { channel: event.channel }),
        asOf: nowIso,
        eventRevision: event.materialRevision,
        status: 'available',
        authority: 'authoritative',
      });
    }
    if (
      event.poolId === undefined ||
      event.channel === undefined ||
      event.totalCapacity === undefined
    ) {
      return rejected('event_unavailable');
    }
    const ledgerSnapshot = await firestore
      .collection(bookingCollections.poolLedgers)
      .doc(finitePoolLedgerId(event.occurrenceId, event.poolId, event.channel))
      .get();
    const ledger = ledgerSnapshot.data() as PoolLedger | undefined;
    const allocated = ledger?.confirmedUnits ?? 0;
    if (allocated < 0) return rejected('event_unavailable');
    const availableUnits = Math.max(0, event.totalCapacity - allocated);
    return succeeded({
      eventId: event.eventId,
      occurrenceId: event.occurrenceId,
      capacityMode: 'finite',
      channel: event.channel,
      asOf: nowIso,
      eventRevision: event.materialRevision,
      status:
        availableUnits === 0
          ? 'soldOut'
          : availableUnits <= Math.max(1, Math.floor(event.totalCapacity / 5))
            ? 'limited'
            : 'available',
      authority: 'authoritative',
      ledgerRevision: ledger?.revision ?? 0,
      availableUnits,
    });
  } catch (error) {
    if (error instanceof BookingDomainRefusal) return rejected(error.code);
    return classifyFirestoreFailure(error, {
      correlationId: query.requestId,
      operationName: 'get_event_availability',
      ...(failureLogger === undefined ? {} : { logger: failureLogger }),
    });
  }
}
