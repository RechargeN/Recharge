import { BookingDomainRefusal } from '../shared/failures.js';
import {
  maximumActiveFiniteBookings,
  maximumActiveUnlimitedBookings,
} from '../security/abuse_policy.js';

export type BookingCapacityMode = 'finite' | 'unlimited';

export interface ActiveBookingUsageSlot {
  readonly bookingId: string;
  readonly expiresAtUtc: string;
}

export interface UserUsage {
  readonly schemaVersion: 2;
  readonly policyVersion: 2;
  readonly actorId: string;
  readonly marketId: 'LV' | 'EE' | 'LT';
  readonly activeFiniteBookings: number;
  readonly activeUnlimitedBookings: number;
  readonly activeFiniteSlots: readonly ActiveBookingUsageSlot[];
  readonly activeUnlimitedSlots: readonly ActiveBookingUsageSlot[];
  readonly revision: number;
  readonly updatedAt: string;
}

export function acquireBookingSlot(
  value: UserUsage | undefined,
  actorId: string,
  marketId: UserUsage['marketId'],
  capacityMode: BookingCapacityMode,
  bookingId: string,
  expiresAtUtc: string,
  now: string,
): UserUsage {
  const current = value ?? {
    schemaVersion: 2 as const,
    policyVersion: 2 as const,
    actorId,
    marketId,
    activeFiniteBookings: 0,
    activeUnlimitedBookings: 0,
    activeFiniteSlots: [] as const,
    activeUnlimitedSlots: [] as const,
    revision: 0,
    updatedAt: now,
  };
  assertUsage(current, actorId, marketId);
  if (
    !/^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(bookingId) ||
    !Number.isFinite(Date.parse(expiresAtUtc)) ||
    Date.parse(expiresAtUtc) <= Date.parse(now)
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  const activeFiniteSlots = prune(current.activeFiniteSlots, now);
  const activeUnlimitedSlots = prune(current.activeUnlimitedSlots, now);
  if (
    activeFiniteSlots.some((slot) => slot.bookingId === bookingId) ||
    activeUnlimitedSlots.some((slot) => slot.bookingId === bookingId)
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
  const currentCount =
    capacityMode === 'finite' ? activeFiniteSlots.length : activeUnlimitedSlots.length;
  const maximum =
    capacityMode === 'finite' ? maximumActiveFiniteBookings : maximumActiveUnlimitedBookings;
  if (currentCount >= maximum) {
    throw new BookingDomainRefusal('active_booking_limit_reached');
  }
  const slot = Object.freeze({ bookingId, expiresAtUtc });
  const nextFiniteSlots =
    capacityMode === 'finite' ? [...activeFiniteSlots, slot] : activeFiniteSlots;
  const nextUnlimitedSlots =
    capacityMode === 'unlimited' ? [...activeUnlimitedSlots, slot] : activeUnlimitedSlots;
  return {
    ...current,
    activeFiniteBookings: nextFiniteSlots.length,
    activeUnlimitedBookings: nextUnlimitedSlots.length,
    activeFiniteSlots: nextFiniteSlots,
    activeUnlimitedSlots: nextUnlimitedSlots,
    revision: current.revision + 1,
    updatedAt: now,
  };
}

export function releaseBookingSlot(
  value: UserUsage,
  actorId: string,
  marketId: UserUsage['marketId'],
  capacityMode: BookingCapacityMode,
  bookingId: string,
  now: string,
): UserUsage {
  assertUsage(value, actorId, marketId);
  const finiteSlots =
    capacityMode === 'finite'
      ? value.activeFiniteSlots.filter((slot) => slot.bookingId !== bookingId)
      : [...value.activeFiniteSlots];
  const unlimitedSlots =
    capacityMode === 'unlimited'
      ? value.activeUnlimitedSlots.filter((slot) => slot.bookingId !== bookingId)
      : [...value.activeUnlimitedSlots];
  return {
    ...value,
    activeFiniteBookings: finiteSlots.length,
    activeUnlimitedBookings: unlimitedSlots.length,
    activeFiniteSlots: finiteSlots,
    activeUnlimitedSlots: unlimitedSlots,
    revision: value.revision + 1,
    updatedAt: now,
  };
}

function assertUsage(current: UserUsage, actorId: string, marketId: UserUsage['marketId']): void {
  if (
    current.actorId !== actorId ||
    current.marketId !== marketId ||
    current.schemaVersion !== 2 ||
    current.policyVersion !== 2 ||
    !Array.isArray(current.activeFiniteSlots) ||
    !Array.isArray(current.activeUnlimitedSlots) ||
    current.activeFiniteBookings !== current.activeFiniteSlots.length ||
    current.activeUnlimitedBookings !== current.activeUnlimitedSlots.length ||
    !current.activeFiniteSlots.every(validSlot) ||
    !current.activeUnlimitedSlots.every(validSlot)
  ) {
    throw new BookingDomainRefusal('event_unavailable');
  }
}

function prune(
  slots: readonly ActiveBookingUsageSlot[],
  now: string,
): readonly ActiveBookingUsageSlot[] {
  const nowMs = Date.parse(now);
  return slots.filter((slot) => Date.parse(slot.expiresAtUtc) > nowMs);
}

function validSlot(value: ActiveBookingUsageSlot): boolean {
  return (
    typeof value === 'object' &&
    value !== null &&
    /^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(value.bookingId) &&
    Number.isFinite(Date.parse(value.expiresAtUtc))
  );
}
