import { BookingDomainRefusal } from '../shared/failures.js';

export interface PoolLedger {
  readonly schemaVersion: 1;
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly poolId: string;
  readonly channel: string;
  readonly totalCapacity: number;
  readonly confirmedUnits: number;
  readonly revision: number;
  readonly updatedAt: string;
}

export function allocateUnits(
  ledger: PoolLedger | undefined,
  identity: Omit<PoolLedger, 'confirmedUnits' | 'revision' | 'updatedAt' | 'schemaVersion'>,
  units: number,
  now: string,
): PoolLedger {
  const current: PoolLedger = ledger ?? {
    schemaVersion: 1,
    ...identity,
    confirmedUnits: 0,
    revision: 0,
    updatedAt: now,
  };
  if (
    current.eventId !== identity.eventId ||
    current.occurrenceId !== identity.occurrenceId ||
    current.poolId !== identity.poolId ||
    current.channel !== identity.channel ||
    current.totalCapacity !== identity.totalCapacity ||
    current.confirmedUnits < 0 ||
    current.confirmedUnits > current.totalCapacity
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  if (current.confirmedUnits + units > current.totalCapacity) {
    throw new BookingDomainRefusal('sold_out');
  }
  return {
    ...current,
    confirmedUnits: current.confirmedUnits + units,
    revision: current.revision + 1,
    updatedAt: now,
  };
}

export function releaseUnits(ledger: PoolLedger, units: number, now: string): PoolLedger {
  if (units < 1 || ledger.confirmedUnits < units)
    throw new BookingDomainRefusal('event_unavailable');
  return {
    ...ledger,
    confirmedUnits: ledger.confirmedUnits - units,
    revision: ledger.revision + 1,
    updatedAt: now,
  };
}
