import assert from 'node:assert/strict';
import test from 'node:test';

import { validateEventBody } from '../../../src/modules/content/domain/type_rules/event_rules.js';
import type {
  ContentValidationContext,
  ReferenceLookups,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';
import { standEventBody } from '../../stand/stand_content.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
const lookups: ReferenceLookups = {
  supportsLocale: () => true,
  subcategoryApplies: (typeId, categoryId, subcategoryId) =>
    typeId === 'event' && categoryId === 'workshops_masterclasses' && subcategoryId === 'pottery',
  requiredCriteria: () => [],
  pointInServiceArea: () => true,
};
const context: ContentValidationContext = {
  typeId: 'event',
  marketId: 'LV',
  publisherRef: { type: 'user', id: userId as never },
  createdByUserId: userId,
  actorUserId: userId,
  nowUtc: '2026-09-29T10:00:00.000Z',
  draftRevision: 1,
  market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
  lookups,
};

type Body = Record<string, unknown>;
const registration = {
  mode: 'internal',
  confirmationMode: 'instant',
  maxPartySize: 3,
  opensMinutesBeforeStart: 10_080,
  closesMinutesBeforeStart: 60,
  cancellationClosesMinutesBeforeStart: 120,
};

function body(change: (value: Body) => void = () => undefined): Body {
  const value = structuredClone(
    standEventBody('cover-asset-1', '0b9b1b2c-5d6e-4f70-8a91-a2b3c4d5e6f7'),
  ) as Body;
  value.participants = { capacityMode: 'known', capacity: 20 };
  value.registration = { ...registration };
  change(value);
  return value;
}

const issues = (value: Body) => validateEventBody(value, context);
const set = (field: string, value: unknown) => (b: Body) => {
  (b.registration as Body)[field] = value;
};

void test('the accepted internal registration v1 body is valid as is', () => {
  assert.deepEqual(issues(body()), []);
  assert.deepEqual(
    issues(body((b) => (b.participants = { capacityMode: 'unlimited' }))),
    [],
    'unlimited capacity',
  );
  assert.deepEqual(issues(body(set('maxPartySize', 1))), [], 'self only');
});

const refusals: readonly [string, (b: Body) => void, string][] = [
  ['no confirmation mode', set('confirmationMode', undefined), 'confirmation_unsupported'],
  ['manual confirmation', set('confirmationMode', 'manualApproval'), 'confirmation_unsupported'],
  ['party size 0', set('maxPartySize', 0), 'party_size_invalid'],
  ['party size 22', set('maxPartySize', 22), 'party_size_invalid'],
  ['no party size (never defaulted)', set('maxPartySize', undefined), 'party_size_invalid'],
  ['opens 0', set('opensMinutesBeforeStart', 0), 'window_invalid'],
  ['opens over a year', set('opensMinutesBeforeStart', 525_601), 'window_invalid'],
  ['closes over a week', set('closesMinutesBeforeStart', 10_081), 'window_invalid'],
  ['closes before it opens', set('closesMinutesBeforeStart', 10_080), 'window_invalid'],
  [
    'cancellation over a week',
    set('cancellationClosesMinutesBeforeStart', 10_081),
    'cancellation_invalid',
  ],
  [
    'cancellation closed before registration opens',
    (b) => {
      set('opensMinutesBeforeStart', 300)(b);
      set('cancellationClosesMinutesBeforeStart', 300)(b);
    },
    'cancellation_invalid',
  ],
  ['absolute window', set('opensAtUtc', '2035-10-01T00:00:00.000Z'), 'window_absolute_unsupported'],
  ['unknown term', set('waitlist', true), 'unknown_field:waitlist'],
  ['no capacity block', (b) => delete b.participants, 'capacity_required'],
  ['unknown capacity', (b) => (b.participants = { capacityMode: 'unknown' }), 'capacity_unknown'],
  [
    'party larger than the capacity',
    (b) => (b.participants = { capacityMode: 'known', capacity: 2 }),
    'party_exceeds_capacity',
  ],
  [
    'paid',
    (b) =>
      (b.pricing = {
        mode: 'fixed',
        price: { amountMinor: 1000, currencyCode: 'EUR' },
        pricingModel: 'per_person',
        paymentCollectionMode: 'onsite',
      }),
    'paid_unsupported',
  ],
  [
    'online',
    (b) => {
      b.format = 'online';
      b.onlineAccessMode = 'publicLink';
      b.publicOnlineUrl = 'https://example.com/live';
      b.location = { marketCityId: 'riga', countryCode: 'LV' };
    },
    'format_unsupported',
  ],
];

for (const [name, change, code] of refusals)
  void test(`internal registration refuses: ${name}`, () => {
    const found = issues(body(change));
    assert.ok(
      found.includes(`event.internal_registration.${code}`),
      `${code} not in ${JSON.stringify(found)}`,
    );
  });

void test('top-level Booking fields stay refused by name next to internal registration', () => {
  for (const key of [
    'guestPolicy',
    'confirmationMode',
    'inventoryPools',
    'registrationDeadlineRule',
  ])
    assert.ok(
      issues(body((b) => (b[key] = {}))).includes(`event.unsupported_capability:${key}`),
      key,
    );
});
