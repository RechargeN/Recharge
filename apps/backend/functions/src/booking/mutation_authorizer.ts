import type { Transaction } from 'firebase-admin/firestore';

import {
  bookingAccessCapability,
  type BookingAccessHint,
} from '../shared/booking_access_authority.js';
import type { BookingFlagId } from '../shared/feature_flags.js';
import { BookingDomainRefusal } from '../shared/failures.js';
import type { BookingAccessDecision } from '../shared/booking_access_authority.js';

export interface TransactionalBookingAccessAuthority {
  authorizeTransaction(
    transaction: Transaction,
    hint: BookingAccessHint,
    now: Date,
    requiredCapability: typeof bookingAccessCapability,
  ): Promise<BookingAccessDecision>;
}

export interface TransactionalFeatureFlagGate {
  isEnabled(capabilityId: BookingFlagId, transaction: Transaction): Promise<boolean>;
}

export interface BookingMutationAuthorization {
  readonly hint: BookingAccessHint;
  readonly flagId: BookingFlagId;
  readonly authority: TransactionalBookingAccessAuthority;
  readonly featureFlags: TransactionalFeatureFlagGate;
}

export async function assertBookingMutationAuthorized(
  transaction: Transaction,
  authorization: BookingMutationAuthorization,
  now: Date,
): Promise<void> {
  const decision = await authorization.authority.authorizeTransaction(
    transaction,
    authorization.hint,
    now,
    bookingAccessCapability,
  );
  if (!decision.allowed) throw new BookingDomainRefusal('permission_denied');
  if (!(await authorization.featureFlags.isEnabled(authorization.flagId, transaction))) {
    throw new BookingDomainRefusal('feature_disabled');
  }
}
