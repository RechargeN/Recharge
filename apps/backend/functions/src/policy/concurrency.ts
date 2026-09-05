import { BookingDomainRefusal } from '../shared/failures.js';

export const maximumActiveFiniteBookings = 5;

export interface UserUsage {
  readonly schemaVersion: 1;
  readonly policyVersion: 1;
  readonly actorId: string;
  readonly activeFiniteBookings: number;
  readonly revision: number;
  readonly updatedAt: string;
}

export function acquireFiniteSlot(
  value: UserUsage | undefined,
  actorId: string,
  now: string,
): UserUsage {
  const current = value ?? {
    schemaVersion: 1 as const,
    policyVersion: 1 as const,
    actorId,
    activeFiniteBookings: 0,
    revision: 0,
    updatedAt: now,
  };
  if (
    current.actorId !== actorId ||
    current.policyVersion !== 1 ||
    current.activeFiniteBookings < 0 ||
    current.activeFiniteBookings > maximumActiveFiniteBookings
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  if (current.activeFiniteBookings >= maximumActiveFiniteBookings) {
    throw new BookingDomainRefusal('concurrency_cap_reached');
  }
  return {
    ...current,
    activeFiniteBookings: current.activeFiniteBookings + 1,
    revision: current.revision + 1,
    updatedAt: now,
  };
}

export function releaseFiniteSlot(value: UserUsage, actorId: string, now: string): UserUsage {
  if (value.actorId !== actorId || value.policyVersion !== 1 || value.activeFiniteBookings < 1) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  return {
    ...value,
    activeFiniteBookings: value.activeFiniteBookings - 1,
    revision: value.revision + 1,
    updatedAt: now,
  };
}
