import type { Firestore } from 'firebase-admin/firestore';
import type { GetEventAvailabilityQuery } from '../contracts/booking_v1.js';
import { type PoolLedger } from '../inventory/ledger.js';
import {
  BookingDomainRefusal,
  rejected,
  retryable,
  succeeded,
  type BookingResult,
} from '../shared/failures.js';
import type { ServerClock } from '../shared/server_clock.js';
import { assertSupportedEvent } from './domain.js';
import { bookingCollections, finitePoolLedgerId } from './transactions.js';

export interface EventAvailability {
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly capacityMode: 'finite' | 'unlimited';
  readonly channel?: 'onsite' | 'online' | 'any';
  readonly asOf: string;
  readonly eventRevision: number;
  readonly status: 'available' | 'limited' | 'soldOut';
  readonly authority: 'authoritative';
  readonly ledgerRevision?: number;
  readonly availableUnits?: number;
}

export async function getEventAvailability(
  firestore: Firestore,
  clock: ServerClock,
  query: GetEventAvailabilityQuery,
): Promise<BookingResult<EventAvailability>> {
  try {
    const eventSnapshot = await firestore
      .collection(bookingCollections.eventProjections)
      .doc(query.payload.occurrenceId)
      .get();
    const raw = eventSnapshot.data();
    const rawPoolId = typeof raw?.poolId === 'string' ? raw.poolId : undefined;
    const event = assertSupportedEvent(
      raw,
      clock.now(),
      query.payload.occurrenceId,
      rawPoolId,
      query.payload.channel,
    );
    if (event.eventId !== query.payload.eventId) return rejected('event_unavailable');
    if (event.capacityMode === 'unlimited') {
      return succeeded({
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        capacityMode: 'unlimited',
        ...(event.channel === undefined ? {} : { channel: event.channel }),
        asOf: clock.now().toISOString(),
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
    if (allocated < 0 || allocated > event.totalCapacity) return rejected('event_unavailable');
    const availableUnits = event.totalCapacity - allocated;
    return succeeded({
      eventId: event.eventId,
      occurrenceId: event.occurrenceId,
      capacityMode: 'finite',
      channel: event.channel,
      asOf: clock.now().toISOString(),
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
    return retryable('temporarily_unavailable');
  }
}
