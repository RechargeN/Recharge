import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bookingOutboxId,
  bookingRefsFor,
  eventTransitionIssues,
  internalPoolId,
  internalRegistrationTerms,
  isMaterialChange,
  planBookingHandoff,
  validateInternalRegistration,
  type HandoffContentState,
  type HandoffEffect,
} from '../../../src/modules/content/domain/event_internal_registration.js';
import { IssueCollector } from '../../../src/modules/content/domain/type_rules/validation_context.js';

type Body = Record<string, unknown>;
const contentId = 'content-1';
const slot = (id: string, localDate: string, start: string, end: string) => ({
  id,
  localDate,
  startAtUtc: start,
  endAtUtc: end,
});
const a = slot('occ-a', '2035-10-10', '2035-10-10T15:00:00.000Z', '2035-10-10T17:00:00.000Z');
const b = slot('occ-b', '2035-10-17', '2035-10-17T15:00:00.000Z', '2035-10-17T17:00:00.000Z');

function body(overrides: Body = {}): Body {
  return {
    format: 'offline',
    location: { city: 'Riga', latitude: 56.95, longitude: 24.1, pinConfirmed: true },
    pricing: { mode: 'free', paymentCollectionMode: 'none' },
    participants: { capacityMode: 'known', capacity: 20 },
    registration: {
      mode: 'internal',
      confirmationMode: 'instant',
      maxPartySize: 3,
      opensMinutesBeforeStart: 10_080,
      closesMinutesBeforeStart: 60,
      cancellationClosesMinutesBeforeStart: 120,
    },
    eventSlots: [a, b],
    ...overrides,
  };
}

let sequence = 0;
function effect(overrides: Partial<HandoffEffect> = {}): HandoffEffect {
  sequence += 1;
  return {
    effectId: `effect-${sequence}`,
    contentId,
    pointerRevision: sequence,
    visibility: 'visible',
    marketId: 'LV',
    publisherRef: { type: 'page', id: 'page-1' },
    occurredAtUtc: '2035-09-01T00:00:00.000Z',
    ...overrides,
  };
}

void test('the server derives every Booking term per occurrence; nothing comes from the client', () => {
  const terms = internalRegistrationTerms(body());
  assert.ok(terms);
  const plan = planBookingHandoff(null, effect({ pointerRevision: 1 }), body());
  const first = plan.facts[0];
  assert.equal(first?.kind, 'EventRevisionPublished');
  assert.ok(first !== undefined && 'projection' in first);
  const projection = first.projection;
  assert.equal(projection.poolId, internalPoolId(contentId, 'occ-a'));
  assert.equal(projection.poolId, internalPoolId(contentId, 'occ-a'), 'stable');
  assert.notEqual(internalPoolId(contentId, 'occ-a'), internalPoolId(contentId, 'occ-b'));
  assert.match(projection.poolId ?? '', /^pool_[0-9a-f]{32}$/u);
  assert.equal(projection.channel, 'onsite');
  assert.equal(projection.capacityMode, 'finite');
  assert.equal(projection.totalCapacity, 20);
  assert.deepEqual(projection.registrationWindow, {
    opensAt: '2035-10-03T15:00:00.000Z',
    closesAt: '2035-10-10T14:00:00.000Z',
  });
  assert.equal(projection.cancellationDeadline, '2035-10-10T13:00:00.000Z');
  assert.deepEqual(projection.guestPolicy, {
    mode: 'partyWithoutNames',
    maximumParticipantUnits: 3,
  });
  assert.equal(projection.materialRevision, 1);
  assert.equal(projection.publicationRevision, 1);

  const unlimited = planBookingHandoff(
    null,
    effect({ pointerRevision: 1 }),
    body({
      participants: { capacityMode: 'unlimited' },
      registration: { ...(body().registration as Body), maxPartySize: 1 },
    }),
  ).facts[0];
  assert.ok(unlimited !== undefined && 'projection' in unlimited);
  assert.equal(unlimited.projection.poolId, undefined, 'Booking needs pool and channel together');
  assert.equal(unlimited.projection.channel, undefined);
  assert.equal(unlimited.projection.guestPolicy.mode, 'selfOnly');
  assert.deepEqual(bookingRefsFor(contentId, body()), [
    { eventId: contentId, occurrenceId: 'occ-a', channel: 'onsite' },
    { eventId: contentId, occurrenceId: 'occ-b', channel: 'onsite' },
  ]);
  assert.equal(internalRegistrationTerms(body({ registration: { mode: 'none' } })), null);
});

void test('D07: a new date or a shift of 120 minutes is material, anything less is not', () => {
  const base = { localDate: '2035-10-10', startAtUtc: '2035-10-10T15:00:00.000Z' };
  assert.equal(isMaterialChange(base, { ...base, startAtUtc: '2035-10-10T16:59:00.000Z' }), false);
  assert.equal(isMaterialChange(base, { ...base, startAtUtc: '2035-10-10T17:00:00.000Z' }), true);
  assert.equal(
    isMaterialChange(base, { localDate: '2035-10-11', startAtUtc: '2035-10-10T15:30:00.000Z' }),
    true,
  );
});

void test('a published internal Event may not change mode, capacity mode, format or venue', () => {
  const forbidden = ['event.internal_registration.transition_unsupported'];
  assert.deepEqual(eventTransitionIssues(null, body()), []);
  assert.deepEqual(eventTransitionIssues(body({ registration: { mode: 'none' } }), body()), []);
  assert.deepEqual(
    eventTransitionIssues(body(), body({ registration: { mode: 'none' } })),
    forbidden,
  );
  assert.deepEqual(
    eventTransitionIssues(body(), body({ participants: { capacityMode: 'unlimited' } })),
    forbidden,
  );
  assert.deepEqual(eventTransitionIssues(body(), body({ format: 'hybrid' })), forbidden);
  assert.deepEqual(
    eventTransitionIssues(
      body(),
      body({ location: { city: 'Riga', latitude: 56.96, longitude: 24.1, pinConfirmed: true } }),
    ),
    forbidden,
    'venue lock',
  );
  assert.deepEqual(
    eventTransitionIssues(
      body(),
      body({ participants: { capacityMode: 'known', capacity: 5 }, eventSlots: [b] }),
    ),
    [],
    'capacity and occurrences may change',
  );
});

void test('the plan: material, non-material, removal before and after start, terminal markers', () => {
  const published = planBookingHandoff(null, effect({ pointerRevision: 1 }), body());
  assert.deepEqual(
    published.facts.map((fact) => [fact.kind, fact.occurrenceId, fact.materialRevision]),
    [
      ['EventRevisionPublished', 'occ-a', 1],
      ['EventRevisionPublished', 'occ-b', 1],
    ],
  );
  // occ-a moves 30 minutes (non-material), occ-b moves a day (material).
  const moved = body({
    eventSlots: [
      { ...a, startAtUtc: '2035-10-10T15:30:00.000Z', endAtUtc: '2035-10-10T17:30:00.000Z' },
      slot('occ-b', '2035-10-18', '2035-10-18T15:00:00.000Z', '2035-10-18T17:00:00.000Z'),
    ],
  });
  const second = planBookingHandoff(published.next, effect({ pointerRevision: 2 }), moved);
  assert.deepEqual(
    second.facts.map((fact) => [
      fact.kind,
      fact.occurrenceId,
      fact.materialRevision,
      fact.publicationRevision,
    ]),
    [
      ['EventRevisionPublished', 'occ-a', 1, 2],
      ['EventMateriallyRescheduled', 'occ-b', 2, 2],
    ],
  );

  // occ-b removed before its start: cancelled and terminal.
  const removed = planBookingHandoff(
    second.next,
    effect({ pointerRevision: 3, occurredAtUtc: '2035-10-01T00:00:00.000Z' }),
    body({ eventSlots: [a] }),
  );
  assert.deepEqual(
    removed.facts.map((fact) => [fact.kind, fact.occurrenceId]),
    [
      ['EventRevisionPublished', 'occ-a'],
      ['EventOccurrenceCancelled', 'occ-b'],
    ],
  );
  assert.equal(removed.next.occurrences['occ-b']?.terminal, 'cancelled');

  // A later revision brings occ-b back: it is not resurrected.
  const back = planBookingHandoff(removed.next, effect({ pointerRevision: 4 }), body());
  assert.deepEqual(
    back.facts.map((fact) => fact.occurrenceId),
    ['occ-a'],
  );
  assert.deepEqual(back.findings, ['occurrence_terminal:occ-b']);

  // Removal decided by the time of the Content change: after the start, no cancel.
  const late = planBookingHandoff(
    published.next,
    effect({ pointerRevision: 2, occurredAtUtc: '2035-10-10T16:00:00.000Z' }),
    body({ eventSlots: [b] }),
  );
  assert.deepEqual(
    late.facts.map((fact) => [fact.kind, fact.occurrenceId]),
    [['EventRevisionPublished', 'occ-b']],
  );
  assert.equal(late.next.occurrences['occ-a']?.terminal, 'past');
});

void test('hide unpublishes every live occurrence; restore publishes again', () => {
  const published = planBookingHandoff(null, effect({ pointerRevision: 1 }), body());
  const hidden = planBookingHandoff(
    published.next,
    effect({ pointerRevision: 2, visibility: 'restricted' }),
    body(),
  );
  assert.deepEqual(
    hidden.facts.map((fact) => [fact.kind, fact.publicationRevision, fact.materialRevision]),
    [
      ['EventUnpublished', 2, 1],
      ['EventUnpublished', 2, 1],
    ],
  );
  const restored = planBookingHandoff(hidden.next, effect({ pointerRevision: 3 }), body());
  assert.deepEqual(
    restored.facts.map((fact) => [fact.kind, fact.publicationRevision]),
    [
      ['EventRevisionPublished', 3],
      ['EventRevisionPublished', 3],
    ],
  );
  const state: HandoffContentState = restored.next;
  const occurrence = state.occurrences['occ-a'];
  assert.equal(occurrence?.lastPublicationRevision, 3);
  assert.equal(
    occurrence?.lastOutboxId,
    bookingOutboxId(restored.next.lastEffectId, restored.facts[0]!),
  );
});

void test('a revision without internal registration closes Booking and is reported', () => {
  const published = planBookingHandoff(null, effect({ pointerRevision: 1 }), body());
  const removed = planBookingHandoff(
    published.next,
    effect({ pointerRevision: 2 }),
    body({ registration: { mode: 'none' } }),
  );
  assert.deepEqual(
    removed.facts.map((fact) => fact.kind),
    ['EventUnpublished', 'EventUnpublished'],
  );
  assert.deepEqual(removed.findings, ['registration_removed']);
});

void test('more than 50 occurrences with internal registration is refused', () => {
  const issues = new IssueCollector();
  validateInternalRegistration(
    body({ eventSlots: Array.from({ length: 51 }, (_, index) => ({ id: `o${index}` })) }),
    issues,
  );
  assert.ok(issues.result().includes('event.internal_registration.too_many_occurrences'));
});
