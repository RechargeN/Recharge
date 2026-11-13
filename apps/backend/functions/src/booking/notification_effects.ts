import { createHash } from 'node:crypto';

import type { Firestore } from 'firebase-admin/firestore';

import {
  createSuppressedOutbox,
  type BookingCancellationCause,
  type BookingNotificationEffectRecord,
  type BookingNotificationEventType,
  type BookingOutboxRecord,
  type SuppressedBookingOutboxRecord,
} from '../notifications/outbox.js';
import { FirestoreFeatureFlagGate } from '../platform/config/firestore_feature_flag_gate.js';
import { bookingNotificationFlagIds } from '../shared/feature_flags.js';
import { notificationOutboxExpiresAt } from './retention.js';

/** F1 test-only relevance window the Booking producer declares (not a product default). */
export const bookingNotificationDeliveryWindowHours = 7 * 24;

export type BookingNotificationEffect =
  | Readonly<{ kind: 'confirmed' }>
  | Readonly<{ kind: 'cancelled'; cause: BookingCancellationCause }>
  | Readonly<{ kind: 'reconfirmationRequired'; reconfirmationDeadlineUtc: string }>
  | Readonly<{ kind: 'reconfirmed' }>;

export interface BookingNotificationSubject {
  readonly id: string;
  readonly userId: string;
  readonly marketId: 'LV' | 'EE' | 'LT';
  readonly eventId: string;
  readonly occurrenceId: string;
}

/**
 * Reads the local producer activation flag before the Booking transaction. The
 * gate is always closed outside the Emulator, so cloud keeps writing v1.
 */
export function bookingNotificationEffectsEnabled(firestore: Firestore): Promise<boolean> {
  return new FirestoreFeatureFlagGate(firestore, 'local', 'LV').isEnabled(
    bookingNotificationFlagIds.effects,
  );
}

/**
 * The Booking outbox record for one committed transition: the unchanged v1
 * `suppressedPreActivation` record while the producer is inactive, otherwise
 * the v2 OD-09 envelope. `actorId` is passed exactly as the v1 call sites do.
 */
export function bookingOutboxRecord(
  active: boolean,
  input: Readonly<{
    effect: BookingNotificationEffect;
    booking: BookingNotificationSubject;
    actorId: string;
    revision: number;
    occurredAt: string;
    correlationId: string;
  }>,
): BookingOutboxRecord {
  if (!active)
    return suppressedRecord(input.effect, input.booking.id, input.actorId, input.occurredAt);
  return notificationEffectRecord(input);
}

function suppressedRecord(
  effect: BookingNotificationEffect,
  bookingId: string,
  actorId: string,
  occurredAt: string,
): SuppressedBookingOutboxRecord {
  const obligation =
    effect.kind === 'confirmed'
      ? 'booking_confirmation'
      : effect.kind === 'cancelled'
        ? 'booking_cancellation'
        : 'booking_reconfirmation';
  return createSuppressedOutbox(obligation, bookingId, actorId, occurredAt);
}

const eventTypes: Readonly<
  Record<BookingNotificationEffect['kind'], BookingNotificationEventType>
> = {
  confirmed: 'booking.confirmed',
  cancelled: 'booking.cancelled',
  reconfirmationRequired: 'booking.reconfirmationRequired',
  reconfirmed: 'booking.reconfirmed',
};

export function notificationEffectRecord(
  input: Readonly<{
    effect: BookingNotificationEffect;
    booking: BookingNotificationSubject;
    actorId: string;
    revision: number;
    occurredAt: string;
    correlationId: string;
  }>,
): BookingNotificationEffectRecord {
  const occurredMs = Date.parse(input.occurredAt);
  if (!input.occurredAt.endsWith('Z') || !Number.isFinite(occurredMs))
    throw new TypeError('booking_notification_time_invalid');
  if (!Number.isSafeInteger(input.revision) || input.revision < 1)
    throw new TypeError('booking_notification_revision_invalid');
  let deliverUntilMs = occurredMs + bookingNotificationDeliveryWindowHours * 3_600_000;
  if (input.effect.kind === 'reconfirmationRequired') {
    const deadlineMs = Date.parse(input.effect.reconfirmationDeadlineUtc);
    if (!Number.isFinite(deadlineMs)) throw new TypeError('booking_notification_deadline_invalid');
    deliverUntilMs = Math.min(deliverUntilMs, deadlineMs);
  }
  const deliverUntilUtc = new Date(deliverUntilMs).toISOString();
  return {
    schemaVersion: 2,
    effectDisposition: 'pending',
    dispatchable: true,
    replayable: true,
    eventId: bookingOutboxId(input.booking.id, input.revision),
    eventType: eventTypes[input.effect.kind],
    eventVersion: 1,
    producer: 'booking',
    aggregateType: 'booking',
    aggregateId: input.booking.id,
    aggregateRevision: input.revision,
    occurredAt: input.occurredAt,
    correlationId: input.correlationId,
    marketId: input.booking.marketId,
    dataClass: 'personal',
    payload: {
      schemaVersion: 1,
      eventContentId: input.booking.eventId,
      occurrenceId: input.booking.occurrenceId,
      ...(input.effect.kind === 'cancelled' ? { cause: input.effect.cause } : {}),
      ...(input.effect.kind === 'reconfirmationRequired'
        ? { reconfirmationDeadlineUtc: input.effect.reconfirmationDeadlineUtc }
        : {}),
      deliverUntilUtc,
    },
    actorId: input.actorId,
    createdAt: input.occurredAt,
    retentionClass: 'bookingOutbox',
    legalHold: false,
    expiresAt: notificationOutboxExpiresAt(deliverUntilUtc),
  };
}

/** Same id as v1 (`suppressedOutboxId`): one record per committed revision. */
export function bookingOutboxId(bookingId: string, revision: number): string {
  return `${bookingId}__r${revision}`;
}

/** Correlation for system-initiated transitions that have no command logical id. */
export function systemCorrelationId(prefix: 'occ' | 'prv', parts: readonly string[]): string {
  return `${prefix}_${createHash('sha256').update(parts.join('|'), 'utf8').digest('hex').slice(0, 32)}`;
}
