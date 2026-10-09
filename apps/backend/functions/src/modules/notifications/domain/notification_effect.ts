import { createHash } from 'node:crypto';

/**
 * F1: the consumer view of one Booking notification obligation (Booking outbox
 * v2, the accepted OD-09 envelope). Booking owns the record; Notifications only
 * validates and reads it. v1 `suppressedPreActivation` records and anything else
 * that is not dispatchable are never activated.
 */
export type NotificationEffectType =
  | 'booking.confirmed'
  | 'booking.cancelled'
  | 'booking.reconfirmationRequired'
  | 'booking.reconfirmed';

export type NotificationCancellationCause =
  'userCancelled' | 'occurrenceCancelled' | 'missedReconfirmation' | 'privacyErasure';

export interface NotificationEffect {
  readonly eventId: string;
  readonly eventType: NotificationEffectType;
  readonly eventVersion: 1;
  readonly producer: 'booking';
  readonly aggregateType: 'booking';
  readonly aggregateId: string;
  readonly aggregateRevision: number;
  readonly occurredAtUtc: string;
  readonly correlationId: string;
  readonly marketId: 'LV' | 'EE' | 'LT';
  /** The Booking subject (`actorId`); the only recipient of a Booking effect. */
  readonly recipientId: string;
  readonly eventContentId: string;
  readonly occurrenceId: string;
  readonly cause?: NotificationCancellationCause;
  readonly reconfirmationDeadlineUtc?: string;
  readonly deliverUntilUtc: string;
}

export type ParsedNotificationEffect =
  | Readonly<{ kind: 'effect'; effect: NotificationEffect }>
  | Readonly<{ kind: 'not_dispatchable' }>
  | Readonly<{ kind: 'invalid'; code: 'invalid_effect' | 'unsupported_effect' }>;

export const notificationConsumer = Object.freeze({ name: 'notifications.inbox', version: 1 });

const eventTypes: readonly NotificationEffectType[] = [
  'booking.confirmed',
  'booking.cancelled',
  'booking.reconfirmationRequired',
  'booking.reconfirmed',
];
const causes: readonly NotificationCancellationCause[] = [
  'userCancelled',
  'occurrenceCancelled',
  'missedReconfirmation',
  'privacyErasure',
];
const markets = ['LV', 'EE', 'LT'] as const;
const idPattern = /^[A-Za-z0-9_.:-]{1,200}$/u;
const envelopeKeys = new Set([
  'schemaVersion',
  'effectDisposition',
  'dispatchable',
  'replayable',
  'eventId',
  'eventType',
  'eventVersion',
  'producer',
  'aggregateType',
  'aggregateId',
  'aggregateRevision',
  'occurredAt',
  'correlationId',
  'marketId',
  'dataClass',
  'payload',
  'actorId',
  'createdAt',
  'retentionClass',
  'legalHold',
  'expiresAt',
]);
const payloadKeys = new Set([
  'schemaVersion',
  'eventContentId',
  'occurrenceId',
  'cause',
  'reconfirmationDeadlineUtc',
  'deliverUntilUtc',
]);

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function isUtcInstant(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/u.test(value) &&
    Number.isFinite(Date.parse(value))
  );
}

function id(value: unknown): value is string {
  return typeof value === 'string' && idPattern.test(value);
}

/**
 * Validates a `bookingOutbox` document. Only `schemaVersion: 2`, `pending`,
 * dispatchable records produced by Booking are effects; the document id must be
 * the OD-09 `eventId`. Unknown versions or types are `unsupported_effect`
 * (quarantined, never guessed); malformed fields are `invalid_effect`.
 */
export function parseNotificationEffect(
  documentId: string,
  data: unknown,
): ParsedNotificationEffect {
  const raw = record(data);
  if (raw === null) return { kind: 'invalid', code: 'invalid_effect' };
  if (raw.dispatchable !== true || raw.schemaVersion === 1) return { kind: 'not_dispatchable' };
  if (raw.schemaVersion !== 2 || raw.eventVersion !== 1)
    return { kind: 'invalid', code: 'unsupported_effect' };
  if (!eventTypes.includes(raw.eventType as NotificationEffectType))
    return { kind: 'invalid', code: 'unsupported_effect' };
  const payload = record(raw.payload);
  const invalid = { kind: 'invalid', code: 'invalid_effect' } as const;
  if (payload === null) return invalid;
  if (Object.keys(raw).some((key) => !envelopeKeys.has(key))) return invalid;
  if (Object.keys(payload).some((key) => !payloadKeys.has(key))) return invalid;
  if (
    raw.effectDisposition !== 'pending' ||
    raw.replayable !== true ||
    raw.producer !== 'booking' ||
    raw.aggregateType !== 'booking' ||
    raw.dataClass !== 'personal' ||
    raw.eventId !== documentId ||
    !id(raw.eventId) ||
    !id(raw.aggregateId) ||
    !id(raw.correlationId) ||
    !id(raw.actorId) ||
    !Number.isSafeInteger(raw.aggregateRevision) ||
    (raw.aggregateRevision as number) < 1 ||
    !isUtcInstant(raw.occurredAt) ||
    !markets.includes(raw.marketId as (typeof markets)[number]) ||
    payload.schemaVersion !== 1 ||
    !id(payload.eventContentId) ||
    !id(payload.occurrenceId) ||
    !isUtcInstant(payload.deliverUntilUtc)
  )
    return invalid;
  const eventType = raw.eventType as NotificationEffectType;
  const cause = payload.cause;
  if ((eventType === 'booking.cancelled') !== (cause !== undefined)) return invalid;
  if (cause !== undefined && !causes.includes(cause as NotificationCancellationCause))
    return invalid;
  const deadline = payload.reconfirmationDeadlineUtc;
  if ((eventType === 'booking.reconfirmationRequired') !== (deadline !== undefined)) return invalid;
  if (deadline !== undefined && !isUtcInstant(deadline)) return invalid;
  return {
    kind: 'effect',
    effect: {
      eventId: raw.eventId,
      eventType,
      eventVersion: 1,
      producer: 'booking',
      aggregateType: 'booking',
      aggregateId: raw.aggregateId,
      aggregateRevision: raw.aggregateRevision as number,
      occurredAtUtc: raw.occurredAt,
      correlationId: raw.correlationId,
      marketId: raw.marketId as NotificationEffect['marketId'],
      recipientId: raw.actorId,
      eventContentId: payload.eventContentId,
      occurrenceId: payload.occurrenceId,
      ...(cause === undefined ? {} : { cause: cause as NotificationCancellationCause }),
      ...(deadline === undefined ? {} : { reconfirmationDeadlineUtc: deadline }),
      deliverUntilUtc: payload.deliverUntilUtc,
    },
  };
}

function sha256(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/** OD-09 consumer dedupe key (consumerName, consumerVersion, eventId); no person id. */
export function notificationReceiptId(eventId: string): string {
  return `nrc_${sha256(`${notificationConsumer.name}|${String(notificationConsumer.version)}|${eventId}`).slice(0, 40)}`;
}

/** The logical inbox record of one receipt; never equal to the receipt id. */
export function notificationIdFor(receiptId: string): string {
  return `ntf_${sha256(`inbox-item|${receiptId}`).slice(0, 32)}`;
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (typeof value === 'object' && value !== null)
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonical((value as Record<string, unknown>)[key])}`)
      .join(',')}}`;
  return JSON.stringify(value);
}

/** Canonical hash of the consumed envelope: a changed redelivery is a conflict. */
export function notificationEffectSha256(effect: NotificationEffect): string {
  return sha256(canonical(effect));
}
