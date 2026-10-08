import type { ContentBody } from '../../../contracts/content_v1.js';
import { canonicalJson, sha256Hex } from './published_revision.js';
import {
  hasOnlyKeys,
  isInt,
  isRecord,
  type IssueCollector,
  type Json,
} from './type_rules/validation_context.js';

/**
 * Event internal registration v1 (E2.0, owner-accepted amendment
 * `docs/product/EVENT_INTERNAL_REGISTRATION_E2_0_AMENDMENT.md`). Pure rules:
 * the accepted body subset, the transitions a published object may not make,
 * the server-side derivation of the Booking projection per occurrence, the D07
 * materiality rule and the plan of Booking facts for one Content effect.
 *
 * Everything here is test-only and Emulator-only: the bounds are not product
 * defaults, and nothing a Creator sends is ever replaced by a default.
 */
export const eventInternalRegistrationConfig = Object.freeze({
  maxPartySize: 21,
  maxOpensMinutesBeforeStart: 525_600,
  maxClosesMinutesBeforeStart: 10_080,
  maxCancellationMinutesBeforeStart: 10_080,
  maxOccurrences: 50,
  /** D07 / BCK-09 §12.6: a start shift of this many minutes is material. */
  materialShiftMinutes: 120,
});

const issue = (name: string): string => `event.internal_registration.${name}`;

const internalKeys = new Set([
  'mode',
  'confirmationMode',
  'maxPartySize',
  'opensMinutesBeforeStart',
  'closesMinutesBeforeStart',
  'cancellationClosesMinutesBeforeStart',
]);
/** An absolute window has its own explicit refusal, not "unknown field". */
const absoluteWindowKeys = ['opensAtUtc', 'closesAtUtc', 'window', 'registrationWindow'];

/** Location fields a published internal Event may not change (venue lock). */
const locationKeys = [
  'marketCityId',
  'countryCode',
  'city',
  'venueName',
  'formattedAddress',
  'meetingPoint',
  'latitude',
  'longitude',
  'pinConfirmed',
  'accuracy',
] as const;

export function isInternalRegistration(body: ContentBody): boolean {
  return isRecord(body.registration) && body.registration.mode === 'internal';
}

/** Body rules of §1 for `registration.mode = 'internal'`. */
export function validateInternalRegistration(body: ContentBody, issues: IssueCollector): void {
  const registration = body.registration as Json;
  const config = eventInternalRegistrationConfig;
  if (absoluteWindowKeys.some((key) => key in registration))
    issues.add(issue('window_absolute_unsupported'));
  hasOnlyKeys(
    registration,
    new Set([...internalKeys, ...absoluteWindowKeys]),
    issues,
    'event.internal_registration',
  );
  issues.require(registration.confirmationMode === 'instant', issue('confirmation_unsupported'));

  const party = registration.maxPartySize;
  const partyOk = isInt(party, 1, config.maxPartySize);
  issues.require(partyOk, issue('party_size_invalid'));
  const opens = registration.opensMinutesBeforeStart;
  const closes = registration.closesMinutesBeforeStart;
  const cancellation = registration.cancellationClosesMinutesBeforeStart;
  const opensOk = isInt(opens, 1, config.maxOpensMinutesBeforeStart);
  // Minutes before the start: a smaller number is a later time.
  issues.require(
    opensOk && isInt(closes, 0, config.maxClosesMinutesBeforeStart) && closes < opens,
    issue('window_invalid'),
  );
  issues.require(
    isInt(cancellation, 0, config.maxCancellationMinutesBeforeStart) &&
      (!opensOk || cancellation < opens),
    issue('cancellation_invalid'),
  );

  const participants = body.participants;
  if (!isRecord(participants)) issues.add(issue('capacity_required'));
  else if (participants.capacityMode === 'unknown') issues.add(issue('capacity_unknown'));
  else if (
    participants.capacityMode === 'known' &&
    partyOk &&
    isInt(participants.capacity, 1, 10_000_000)
  )
    issues.require(party <= participants.capacity, issue('party_exceeds_capacity'));
  issues.require(isRecord(body.pricing) && body.pricing.mode === 'free', issue('paid_unsupported'));
  issues.require(body.format === 'offline', issue('format_unsupported'));
  if (Array.isArray(body.eventSlots))
    issues.require(body.eventSlots.length <= config.maxOccurrences, issue('too_many_occurrences'));
}

function capacityModeOf(body: ContentBody): unknown {
  return isRecord(body.participants) ? body.participants.capacityMode : undefined;
}

function locationOf(body: ContentBody): string {
  const location = isRecord(body.location) ? body.location : {};
  return canonicalJson(Object.fromEntries(locationKeys.map((key) => [key, location[key]])));
}

/**
 * §2: what a published internal Event may not become. Checked where the
 * publication pointer actually switches (publish and rollback), against the
 * revision the pointer held before, whatever its hold.
 */
export function eventTransitionIssues(
  from: ContentBody | null,
  to: ContentBody,
): readonly string[] {
  if (from === null || !isInternalRegistration(from)) return [];
  const forbidden =
    !isInternalRegistration(to) ||
    capacityModeOf(from) !== capacityModeOf(to) ||
    from.format !== to.format ||
    locationOf(from) !== locationOf(to);
  return forbidden ? [issue('transition_unsupported')] : [];
}

export interface OccurrenceSlot {
  readonly id: string;
  /** Local date of the start in the Event time zone (validated by Content). */
  readonly localDate: string;
  readonly startAtUtc: string;
  readonly endAtUtc: string;
}

export interface InternalRegistrationTerms {
  readonly capacityMode: 'finite' | 'unlimited';
  readonly totalCapacity: number | null;
  readonly maxPartySize: number;
  readonly opensMinutesBeforeStart: number;
  readonly closesMinutesBeforeStart: number;
  readonly cancellationClosesMinutesBeforeStart: number;
  readonly occurrences: readonly OccurrenceSlot[];
}

/** The terms of an accepted internal registration body; null for anything else. */
export function internalRegistrationTerms(body: ContentBody): InternalRegistrationTerms | null {
  if (!isInternalRegistration(body)) return null;
  const registration = body.registration as Json;
  const participants = isRecord(body.participants) ? body.participants : null;
  const mode = participants?.capacityMode;
  const party = registration.maxPartySize;
  const opens = registration.opensMinutesBeforeStart;
  const closes = registration.closesMinutesBeforeStart;
  const cancellation = registration.cancellationClosesMinutesBeforeStart;
  if (
    (mode !== 'known' && mode !== 'unlimited') ||
    typeof party !== 'number' ||
    typeof opens !== 'number' ||
    typeof closes !== 'number' ||
    typeof cancellation !== 'number' ||
    !Array.isArray(body.eventSlots)
  )
    return null;
  const capacity = participants?.capacity;
  if (mode === 'known' && typeof capacity !== 'number') return null;
  const occurrences: OccurrenceSlot[] = [];
  for (const slot of body.eventSlots) {
    if (
      !isRecord(slot) ||
      typeof slot.id !== 'string' ||
      typeof slot.localDate !== 'string' ||
      typeof slot.startAtUtc !== 'string' ||
      typeof slot.endAtUtc !== 'string'
    )
      return null;
    occurrences.push({
      id: slot.id,
      localDate: slot.localDate,
      startAtUtc: slot.startAtUtc,
      endAtUtc: slot.endAtUtc,
    });
  }
  return {
    capacityMode: mode === 'known' ? 'finite' : 'unlimited',
    totalCapacity: mode === 'known' ? (capacity as number) : null,
    maxPartySize: party,
    opensMinutesBeforeStart: opens,
    closesMinutesBeforeStart: closes,
    cancellationClosesMinutesBeforeStart: cancellation,
    occurrences,
  };
}

/** Server-generated, stable inventory pool id of one occurrence (finite only). */
export function internalPoolId(contentId: string, occurrenceId: string): string {
  return `pool_${sha256Hex(`event-internal-pool-v1|${contentId}|${occurrenceId}`).slice(0, 32)}`;
}

/** D07: a new local start date or a start shift of 120 minutes or more. */
export function isMaterialChange(
  previous: { readonly localDate: string; readonly startAtUtc: string },
  next: { readonly localDate: string; readonly startAtUtc: string },
): boolean {
  return (
    previous.localDate !== next.localDate ||
    Math.abs(Date.parse(next.startAtUtc) - Date.parse(previous.startAtUtc)) >=
      eventInternalRegistrationConfig.materialShiftMinutes * 60_000
  );
}

function minutesBefore(instant: string, minutes: number): string {
  return new Date(Date.parse(instant) - minutes * 60_000).toISOString();
}

export type BookingMarketId = 'LV' | 'EE' | 'LT';

/** The `bookingEventProjections` shape BCK-09 accepts for free internal Booking. */
export interface EventBookingProjectionV1 {
  readonly schemaVersion: 1;
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly marketId: BookingMarketId;
  readonly publisherRef: { readonly type: 'user' | 'page'; readonly id: string };
  readonly materialRevision: number;
  readonly publicationRevision: number;
  readonly occurrenceStartsAt: string;
  readonly occurrenceEndsAt: string;
  readonly lifecycle: 'published';
  readonly bookingEnabled: true;
  readonly registrationMode: 'internal';
  readonly pricingMode: 'free';
  readonly paymentCollectionMode: 'none';
  readonly confirmationMode: 'instant';
  readonly inventoryAuthority: 'internal';
  readonly inventoryShape: 'general';
  readonly capacityMode: 'finite' | 'unlimited';
  readonly totalCapacity?: number;
  readonly poolId?: string;
  readonly channel?: 'onsite';
  readonly registrationWindow: { readonly opensAt: string; readonly closesAt: string };
  readonly cancellationDeadline: string;
  readonly guestPolicy: {
    readonly mode: 'selfOnly' | 'partyWithoutNames';
    readonly maximumParticipantUnits: number;
  };
  readonly eligibilityMode: 'open';
}

export type EventBookingFactV1 =
  | {
      readonly kind: 'EventRevisionPublished' | 'EventMateriallyRescheduled';
      readonly eventId: string;
      readonly occurrenceId: string;
      readonly publicationRevision: number;
      readonly materialRevision: number;
      readonly occurredAt: string;
      readonly projection: EventBookingProjectionV1;
    }
  | {
      readonly kind: 'EventUnpublished' | 'EventOccurrenceCancelled';
      readonly eventId: string;
      readonly occurrenceId: string;
      readonly publicationRevision: number;
      readonly materialRevision: number;
      readonly occurredAt: string;
    };

/** §3: the whole projection is derived on the server from the revision. */
export function bookingProjectionFor(input: {
  readonly contentId: string;
  readonly marketId: BookingMarketId;
  readonly publisherRef: { readonly type: 'user' | 'page'; readonly id: string };
  readonly terms: InternalRegistrationTerms;
  readonly occurrence: OccurrenceSlot;
  readonly materialRevision: number;
  readonly publicationRevision: number;
}): EventBookingProjectionV1 {
  const { terms, occurrence } = input;
  const finite = terms.capacityMode === 'finite';
  return {
    schemaVersion: 1,
    eventId: input.contentId,
    occurrenceId: occurrence.id,
    marketId: input.marketId,
    publisherRef: { type: input.publisherRef.type, id: input.publisherRef.id },
    materialRevision: input.materialRevision,
    publicationRevision: input.publicationRevision,
    occurrenceStartsAt: occurrence.startAtUtc,
    occurrenceEndsAt: occurrence.endAtUtc,
    lifecycle: 'published',
    bookingEnabled: true,
    registrationMode: 'internal',
    pricingMode: 'free',
    paymentCollectionMode: 'none',
    confirmationMode: 'instant',
    inventoryAuthority: 'internal',
    inventoryShape: 'general',
    capacityMode: terms.capacityMode,
    ...(finite
      ? {
          totalCapacity: terms.totalCapacity as number,
          poolId: internalPoolId(input.contentId, occurrence.id),
          channel: 'onsite' as const,
        }
      : {}),
    registrationWindow: {
      opensAt: minutesBefore(occurrence.startAtUtc, terms.opensMinutesBeforeStart),
      closesAt: minutesBefore(occurrence.startAtUtc, terms.closesMinutesBeforeStart),
    },
    cancellationDeadline: minutesBefore(
      occurrence.startAtUtc,
      terms.cancellationClosesMinutesBeforeStart,
    ),
    guestPolicy: {
      mode: terms.maxPartySize === 1 ? 'selfOnly' : 'partyWithoutNames',
      maximumParticipantUnits: terms.maxPartySize,
    },
    eligibilityMode: 'open',
  };
}

/** The Catalog's booking reference: the same derivation, never client logic. */
export function bookingRefsFor(
  contentId: string,
  body: ContentBody,
): readonly {
  readonly eventId: string;
  readonly occurrenceId: string;
  readonly channel?: 'onsite';
}[] {
  const terms = internalRegistrationTerms(body);
  if (terms === null) return [];
  return terms.occurrences.map((occurrence) => ({
    eventId: contentId,
    occurrenceId: occurrence.id,
    ...(terms.capacityMode === 'finite' ? { channel: 'onsite' as const } : {}),
  }));
}

export interface HandoffOccurrenceState {
  readonly occurrenceId: string;
  readonly materialRevision: number;
  readonly localDate: string;
  readonly startAtUtc: string;
  /** A removed occurrence never comes back (§4). */
  readonly terminal: 'cancelled' | 'past' | null;
  /** Publication revision of the last fact sent to Booking (reconciliation). */
  readonly lastPublicationRevision: number;
  /** Create-only outbox id of that fact; null when none was sent. */
  readonly lastOutboxId: string | null;
}

export interface HandoffContentState {
  readonly schemaVersion: 1;
  readonly contentId: string;
  readonly lastPointerRevision: number;
  readonly lastEffectId: string;
  readonly occurrences: Readonly<Record<string, HandoffOccurrenceState>>;
}

/** The minimized Content effect the plan needs. */
export interface HandoffEffect {
  readonly effectId: string;
  readonly contentId: string;
  readonly pointerRevision: number;
  readonly visibility: string;
  readonly marketId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
  readonly occurredAtUtc: string;
}

export interface HandoffPlan {
  readonly facts: readonly EventBookingFactV1[];
  readonly next: HandoffContentState;
  readonly findings: readonly string[];
}

/**
 * §5: the Booking facts of exactly one Content effect, applied on top of the
 * handoff state of its object. The caller guarantees effects arrive in
 * `pointerRevision` order without gaps; this function never skips one.
 */
export function planBookingHandoff(
  state: HandoffContentState | null,
  effect: HandoffEffect,
  body: ContentBody | null,
): HandoffPlan {
  const occurrences: Record<string, HandoffOccurrenceState> = { ...(state?.occurrences ?? {}) };
  const facts: EventBookingFactV1[] = [];
  const findings: string[] = [];
  const publication = effect.pointerRevision;
  const occurredAt = effect.occurredAtUtc;
  const terms = body === null ? null : internalRegistrationTerms(body);
  const marketOk = effect.marketId === 'LV' || effect.marketId === 'EE' || effect.marketId === 'LT';
  const publisherOk = effect.publisherRef.type === 'user' || effect.publisherRef.type === 'page';
  const emit = (
    fact: EventBookingFactV1,
    update: Omit<HandoffOccurrenceState, 'lastPublicationRevision' | 'lastOutboxId'>,
  ) => {
    facts.push(fact);
    occurrences[fact.occurrenceId] = {
      ...update,
      lastPublicationRevision: publication,
      lastOutboxId: bookingOutboxId(effect.effectId, fact),
    };
  };
  const unpublishAll = () => {
    for (const current of Object.values(occurrences))
      if (current.terminal === null)
        emit(
          {
            kind: 'EventUnpublished',
            eventId: effect.contentId,
            occurrenceId: current.occurrenceId,
            publicationRevision: publication,
            materialRevision: current.materialRevision,
            occurredAt,
          },
          current,
        );
  };

  if (effect.visibility !== 'visible') unpublishAll();
  else if (terms === null || !marketOk || !publisherOk) {
    // Content forbids leaving internal registration (§2); should a revision
    // still arrive without it, Booking closes instead of guessing.
    if (Object.values(occurrences).some((current) => current.terminal === null))
      findings.push(terms === null ? 'registration_removed' : 'source_invalid');
    unpublishAll();
  } else {
    const listed = new Set<string>();
    for (const occurrence of terms.occurrences) {
      listed.add(occurrence.id);
      const current = occurrences[occurrence.id];
      if (current?.terminal !== null && current?.terminal !== undefined) {
        findings.push(`occurrence_terminal:${occurrence.id}`);
        continue;
      }
      const material = current === undefined ? false : isMaterialChange(current, occurrence);
      const materialRevision =
        current === undefined ? 1 : current.materialRevision + (material ? 1 : 0);
      emit(
        {
          kind: material ? 'EventMateriallyRescheduled' : 'EventRevisionPublished',
          eventId: effect.contentId,
          occurrenceId: occurrence.id,
          publicationRevision: publication,
          materialRevision,
          occurredAt,
          projection: bookingProjectionFor({
            contentId: effect.contentId,
            marketId: effect.marketId,
            publisherRef: effect.publisherRef as { type: 'user' | 'page'; id: string },
            terms,
            occurrence,
            materialRevision,
            publicationRevision: publication,
          }),
        },
        {
          occurrenceId: occurrence.id,
          materialRevision,
          localDate: occurrence.localDate,
          startAtUtc: occurrence.startAtUtc,
          terminal: null,
        },
      );
    }
    for (const current of Object.values(occurrences)) {
      if (current.terminal !== null || listed.has(current.occurrenceId)) continue;
      // Decided by the time of the Content change, not of a late processing.
      const beforeStart = Date.parse(occurredAt) < Date.parse(current.startAtUtc);
      if (beforeStart)
        emit(
          {
            kind: 'EventOccurrenceCancelled',
            eventId: effect.contentId,
            occurrenceId: current.occurrenceId,
            publicationRevision: publication,
            materialRevision: current.materialRevision,
            occurredAt,
          },
          { ...current, terminal: 'cancelled' },
        );
      else occurrences[current.occurrenceId] = { ...current, terminal: 'past' };
    }
  }
  return {
    facts,
    findings,
    next: {
      schemaVersion: 1,
      contentId: effect.contentId,
      lastPointerRevision: effect.pointerRevision,
      lastEffectId: effect.effectId,
      occurrences,
    },
  };
}

/** Deterministic, create-only outbox id of one fact. */
export function bookingOutboxId(effectId: string, fact: EventBookingFactV1): string {
  return `ebh_${sha256Hex(`${effectId}|${fact.occurrenceId}|${fact.kind}`).slice(0, 40)}`;
}
