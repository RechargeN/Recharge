import { randomBytes, randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { scenarioStopsFor } from '../../src/content_entry.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { FirestoreScenarioService } from '../../src/modules/quick_plan/firestore_scenario_service.js';
import type { ServerClock } from '../../src/shared/server_clock.js';
import { createPlaceWorld, expectData } from './content_place_world.js';

export { expectData };

type Json = Record<string, unknown>;

/** Markers that must never appear in any public, unlisted or Catalog answer. */
export const i3PrivateMarkers = Object.freeze([
  'PRIVATE-home',
  'PRIVATE-street',
  'PRIVATE-note',
  'SNAPSHOT-title',
]);

export const i3Ulid = () => '0' + randomBytes(13).toString('hex').slice(0, 25).toUpperCase();

const time = (hour: number) => ({
  type: 'template',
  startDayIndex: 0,
  preferredStart: { hour, minute: 0 },
  windowStart: null,
  windowEnd: null,
  windowEndDayOffset: 0,
  endDayIndex: null,
  preferredEnd: null,
  startTimezoneId: null,
  endTimezoneId: null,
});

/**
 * An I2 Scenario draft (mobile mapper shape) with every kind of field the
 * distribution must drop or keep: two own public places (A, F), a catalog Place
 * stop (B) with its own location and a presentation snapshot, a time block (C),
 * an approximate place (D), and an unscheduled private stop (E) with a note.
 * `minimal` keeps only A and B, so one unavailable stop drops it below two.
 */
export function i3ScenarioDraft(input: {
  readonly placeId: string;
  readonly title?: string;
  readonly revision?: number;
  readonly minimal?: boolean;
  readonly dated?: boolean;
  readonly routeStop?: string;
}): Json {
  const [day, a, b, c, d, e, f] = Array.from({ length: 7 }, () => randomUUID() as string) as [
    string,
    string,
    string,
    string,
    string,
    string,
    string,
  ];
  const [l1, l2, l3, l4, l5] = Array.from({ length: 5 }, () => randomUUID() as string) as [
    string,
    string,
    string,
    string,
    string,
  ];
  const cost = (minor: number | null) => ({
    components:
      minor === null
        ? [
            {
              componentCode: 'ticket',
              knowledge: 'unknown',
              amount: null,
              basis: null,
              source: 'manual',
              observedAtUtc: null,
              confidence: null,
            },
          ]
        : [
            {
              componentCode: 'ticket',
              knowledge: 'known',
              amount: { minorUnits: minor, currencyCode: 'EUR' },
              basis: 'per_person',
              source: 'manual',
              observedAtUtc: null,
              confidence: null,
            },
          ],
  });
  const item = (id: string, kind: string, source: Json, loc: string | null, extra: Json = {}) => ({
    id,
    dayId: day,
    startLocationId: loc,
    endLocationId: loc,
    kind,
    source,
    sourceStatus: 'ready',
    schedule: {
      mode: 'flexible',
      planned:
        input.dated === true
          ? {
              type: 'dated',
              fixedStartAtUtc: '2030-06-01T08:00:00.000Z',
              fixedEndAtUtc: null,
              windowStart: null,
              windowEnd: null,
              windowEndDayOffset: 0,
              startTimezoneId: 'Europe/Riga',
              endTimezoneId: null,
            }
          : time(10),
      calculated: null,
    },
    durationMinutes: 60,
    cost: cost(null),
    orderLocked: false,
    timeLocked: false,
    role: 'optional',
    alternativeGroupId: null,
    selected: false,
    publicNote: '',
    ...extra,
  });
  const location = (id: string, title: string, disclosure: string, extra: Json = {}) => ({
    id,
    point: { latitude: 56.9496, longitude: 24.1052 },
    title,
    address: null,
    marketId: 'LV',
    regionId: null,
    timezoneId: 'Europe/Riga',
    disclosure,
    sourceObjectId: null,
    sourceObjectType: null,
    ...extra,
  });
  const items: Json[] = [
    item(a, 'visit', { type: 'custom_location', locationId: l1 }, l1, {
      role: 'mandatory',
      publicNote: 'Start at the Old Town square',
      cost: cost(500),
    }),
    item(
      b,
      input.routeStop === undefined ? 'visit' : 'route',
      {
        type: 'catalog',
        objectId: input.routeStop ?? input.placeId,
        objectType: input.routeStop === undefined ? 'place' : 'route',
        snapshot: {
          title: 'SNAPSHOT-title',
          coverMediaId: null,
          publisherId: null,
          sourceLocationVersion: 1,
          durationMinutes: 30,
          distanceM: null,
          checkedAtUtc: null,
        },
      },
      l2,
    ),
  ];
  const locations = [
    location(l1, 'Old Town square', 'public', { address: 'Town Hall Square 1' }),
    location(l2, 'Catalog place location', 'public', {
      point: { latitude: 56.95, longitude: 24.11 },
      sourceObjectId: input.placeId,
      sourceObjectType: 'place',
    }),
  ];
  const legs: Json[] = [];
  const dayItems = [a, b];
  if (input.minimal !== true) {
    items.push(
      item(c, 'time_block', { type: 'time_block', title: 'Lunch break', categoryId: null }, null),
      item(d, 'activity', { type: 'custom_location', locationId: l3 }, l3),
      item(f, 'visit', { type: 'custom_location', locationId: l5 }, l5),
      {
        ...item(e, 'visit', { type: 'custom_location', locationId: l4 }, l4, {
          publicNote: 'PRIVATE-note',
        }),
        dayId: null,
      },
    );
    locations.push(
      location(l3, 'Riverside viewpoint', 'approximate', {
        point: { latitude: 56.95123, longitude: 24.11234 },
        address: 'PRIVATE-street 9',
      }),
      location(l4, 'PRIVATE-home', 'private', { address: 'PRIVATE-street 1' }),
      location(l5, 'Dome cathedral', 'public', { point: { latitude: 56.949, longitude: 24.104 } }),
    );
    dayItems.push(c, d, f);
    const leg = (from: string, to: string, fromL: string, toL: string) => ({
      id: randomUUID(),
      dayId: day,
      fromItemId: from,
      toItemId: to,
      fromLocationId: fromL,
      toLocationId: toL,
      mode: 'walking',
      source: 'manual',
      status: 'ready',
      distanceM: 450,
      durationMinutes: 6,
      cost: { components: [] },
      displayPolyline: [
        { latitude: 56.9496, longitude: 24.1052 },
        { latitude: 56.949, longitude: 24.104 },
      ],
      providerCode: 'PRIVATE-provider',
      warningCode: null,
      updatedAtUtc: null,
      scheduleSnapshot: null,
      lockedByUser: false,
    });
    legs.push(leg(a, f, l1, l5), leg(f, d, l5, l3));
  }
  return {
    title: input.title ?? 'Riga old town walk',
    scenario: {
      schemaVersion: 2,
      updatesEnabled: true,
      revision: input.revision ?? 1,
      format: 'day',
      dateMode: input.dated === true ? 'dated' : 'template',
      defaultTimezoneId: 'Europe/Riga',
      displayCurrencyCode: 'EUR',
      party: { peopleCount: 2, kind: 'couple' },
      constraints: { pace: 'balanced' },
      days: [
        {
          id: day,
          title: 'Old town',
          dayIndex: 0,
          timezoneId: 'Europe/Riga',
          localDate: input.dated === true ? { year: 2030, month: 6, day: 1 } : null,
          startLocationId: null,
          endLocationId: null,
          preferredStartTime: null,
          preferredEndTime: null,
          itemIds: dayItems,
        },
      ],
      locations,
      items,
      unscheduledItemIds: input.minimal === true ? [] : [e],
      legs,
      totals: { private: 'PRIVATE-note' },
      origin: null,
      capabilities: { publicPublish: false, unlistedShare: false, liveLogistics: false },
    },
  };
}

/** A non-Creator User with a current Session (Planning hint and owner id). */
export async function i3Identity(firestore: Firestore, name: string, now: Date) {
  const session = await establishEmulatorIdentitySession({
    firestore,
    firebaseUid: name,
    installationId: name,
    attemptRequestId: randomUUID(),
    now,
  });
  return {
    userId: session.userId,
    hint: {
      firebaseUid: name,
      installationId: name,
      sessionId: session.sessionId,
      sessionHandle: session.sessionHandle,
    },
  };
}
export type I3Actor = Awaited<ReturnType<typeof i3Identity>>;

/**
 * I3 Emulator world: the D3.1 Place world (verified Creator, staff, Media and
 * C2 moderation) with Scenario enabled in Content, plus the Planning service
 * with the Catalog-owned stop status, exactly as the Functions compose it.
 */
export function createScenarioWorld(firestore: Firestore, label: string, clock?: ServerClock) {
  const world = createPlaceWorld(firestore, label, {
    enabledTypes: new Set(['event', 'place', 'scenario'] as const),
  });
  const planning = new FirestoreScenarioService(
    firestore,
    clock ?? { now: () => new Date() },
    scenarioStopsFor(firestore),
  );
  async function owner(): Promise<I3Actor> {
    const { creator } = await world.actors;
    return {
      userId: creator.actor.userId,
      hint: {
        firebaseUid: creator.firebaseUid,
        installationId: creator.installationId,
        sessionId: creator.actor.sessionId,
        sessionHandle: creator.sessionHandle,
      },
    };
  }
  const command = (
    actor: I3Actor,
    scenarioId: string,
    commandType: string,
    expectedRevision: number,
    extra: Json = {},
  ): Json => ({
    schemaVersion: 1,
    requestId: randomUUID(),
    actorContext: actor.userId,
    idempotencyKey: randomUUID(),
    commandType,
    scenarioId,
    expectedRevision,
    generation: 0,
    ...extra,
  });
  return { ...world, planning, owner, command };
}
