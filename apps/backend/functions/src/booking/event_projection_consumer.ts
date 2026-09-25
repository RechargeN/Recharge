import { createHash } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import type { BookingEventProjection } from './domain.js';
import { bookingCollections } from './transactions.js';

export type EventBookingProjectionEvent =
  | Readonly<{
      kind: 'EventRevisionPublished' | 'EventMateriallyRescheduled';
      eventId: string;
      occurrenceId: string;
      publicationRevision: number;
      materialRevision: number;
      occurredAt: string;
      projection: BookingEventProjection;
    }>
  | Readonly<{
      kind: 'EventUnpublished' | 'EventOccurrenceCancelled';
      eventId: string;
      occurrenceId: string;
      publicationRevision: number;
      materialRevision: number;
      occurredAt: string;
    }>;

export type EventProjectionConsumptionResult =
  | Readonly<{ kind: 'applied'; occurrenceId: string; materialRevision: number }>
  | Readonly<{ kind: 'ignoredDuplicate' | 'ignoredStale'; occurrenceId: string }>
  | Readonly<{
      kind: 'rejected';
      code: 'missing_occurrence' | 'invalid_event' | 'revision_conflict';
    }>;

interface StoredProjectionEnvelope {
  readonly eventId?: string;
  readonly occurrenceId?: string;
  readonly materialRevision?: number;
  readonly publicationRevision?: number;
  readonly sourceEventKind?: EventBookingProjectionEvent['kind'];
  readonly sourceEventDigest?: string;
}

/**
 * BCK-07/BCK-09 handoff. This consumer is the sole writer of the Booking
 * projection. It never mutates Event publication state.
 */
export async function consumeEventForBookingProjection(
  firestore: Firestore,
  event: EventBookingProjectionEvent,
): Promise<EventProjectionConsumptionResult> {
  if (!validEventIdentity(event)) return { kind: 'rejected', code: 'missing_occurrence' };
  if (!validRevision(event.materialRevision) || !validRevision(event.publicationRevision)) {
    return { kind: 'rejected', code: 'invalid_event' };
  }
  if (!Number.isFinite(Date.parse(event.occurredAt))) {
    return { kind: 'rejected', code: 'invalid_event' };
  }
  if ('projection' in event && !validPublishedProjection(event)) {
    return { kind: 'rejected', code: 'invalid_event' };
  }

  const ref = firestore.collection(bookingCollections.eventProjections).doc(event.occurrenceId);
  const sourceEventDigest = eventDigest(event);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const existing = snapshot.data() as StoredProjectionEnvelope | undefined;
    if (existing !== undefined) {
      if (existing.eventId !== event.eventId || existing.occurrenceId !== event.occurrenceId) {
        return { kind: 'rejected', code: 'revision_conflict' } as const;
      }
      const currentMaterial = existing.materialRevision ?? -1;
      const currentPublication = existing.publicationRevision ?? -1;
      if (event.materialRevision < currentMaterial) {
        return { kind: 'ignoredStale', occurrenceId: event.occurrenceId } as const;
      }
      if (
        event.materialRevision === currentMaterial &&
        event.publicationRevision < currentPublication
      ) {
        return { kind: 'ignoredStale', occurrenceId: event.occurrenceId } as const;
      }
      if (
        event.materialRevision === currentMaterial &&
        event.publicationRevision === currentPublication
      ) {
        return existing.sourceEventKind === event.kind &&
          (existing.sourceEventDigest === undefined ||
            existing.sourceEventDigest === sourceEventDigest)
          ? ({ kind: 'ignoredDuplicate', occurrenceId: event.occurrenceId } as const)
          : ({ kind: 'rejected', code: 'revision_conflict' } as const);
      }
    }

    if ('projection' in event) {
      transaction.set(ref, {
        ...event.projection,
        publicationRevision: event.publicationRevision,
        sourceEventKind: event.kind,
        sourceEventDigest,
        projectedAt: event.occurredAt,
      });
    } else {
      transaction.set(ref, {
        schemaVersion: 1,
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        publicationRevision: event.publicationRevision,
        materialRevision: event.materialRevision,
        lifecycle: event.kind === 'EventUnpublished' ? 'unpublished' : 'occurrenceCancelled',
        bookingEnabled: false,
        sourceEventKind: event.kind,
        sourceEventDigest,
        projectedAt: event.occurredAt,
      });
    }
    return {
      kind: 'applied',
      occurrenceId: event.occurrenceId,
      materialRevision: event.materialRevision,
    } as const;
  });
}

function eventDigest(event: EventBookingProjectionEvent): string {
  return createHash('sha256')
    .update(JSON.stringify(canonicalize(event)), 'utf8')
    .digest('hex');
}

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (typeof value === 'object' && value !== null) {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, canonicalize(child)]),
    );
  }
  return value;
}

export async function rebuildBookingEventProjections(
  firestore: Firestore,
  events: readonly EventBookingProjectionEvent[],
): Promise<readonly EventProjectionConsumptionResult[]> {
  const ordered = [...events].sort(
    (left, right) =>
      left.materialRevision - right.materialRevision ||
      left.publicationRevision - right.publicationRevision ||
      left.kind.localeCompare(right.kind),
  );
  const results: EventProjectionConsumptionResult[] = [];
  for (const event of ordered) {
    results.push(await consumeEventForBookingProjection(firestore, event));
  }
  return Object.freeze(results);
}

function validEventIdentity(event: EventBookingProjectionEvent): boolean {
  return event.eventId.trim().length > 0 && event.occurrenceId.trim().length > 0;
}

function validRevision(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 1;
}

function validPublishedProjection(
  event: Extract<
    EventBookingProjectionEvent,
    { kind: 'EventRevisionPublished' | 'EventMateriallyRescheduled' }
  >,
): boolean {
  const projection = event.projection;
  return (
    projection.schemaVersion === 1 &&
    projection.eventId === event.eventId &&
    projection.occurrenceId === event.occurrenceId &&
    projection.materialRevision === event.materialRevision &&
    projection.lifecycle === 'published' &&
    projection.bookingEnabled === true
  );
}
