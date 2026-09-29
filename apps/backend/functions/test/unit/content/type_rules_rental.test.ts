/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call --
   Mutation table: each case edits a deeply nested clone of a valid JSON body, and
   the rules under test accept arbitrary untyped input by design. */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import {
  rentalDefaultLimits,
  rentalMediaIds,
  validateRentalBody,
} from '../../../src/modules/content/domain/type_rules/rental_rules.js';
import type {
  ContentValidationContext,
  ReferenceLookups,
  RentalMarketPolicy,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
const id = (suffix: string) => `018FQ2Z8Q9N4M7K2T6V3W1X5${suffix}`;

const policy: RentalMarketPolicy = {
  enabled: true,
  policyVersion: 'rental-policy-1',
  coverageFreshnessDays: 7,
  absoluteMinMinutes: 60,
  absoluteMaxMinutes: 129600,
  minApproximatePrecisionMeters: 300,
  maxDeliveryRadiusKm: 50,
  requiresSizeOrVariant: true,
  requiresMinRenterAge: true,
  requiresIdAtHandover: false,
  requiresSafetyNotice: true,
};

function lookupsWith(rentalPolicy: RentalMarketPolicy | undefined): ReferenceLookups {
  return {
    supportsLocale: () => true,
    subcategoryApplies: () => true,
    requiredCriteria: () => [],
    pointInServiceArea: () => true,
    rentalPolicy: (categoryId, subcategoryId) =>
      categoryId === 'sport' && subcategoryId === 'cycling' ? rentalPolicy : undefined,
  };
}

function context(overrides: Partial<ContentValidationContext> = {}): ContentValidationContext {
  return {
    typeId: 'rental',
    marketId: 'LV',
    publisherRef: { type: 'user', id: userId as never },
    createdByUserId: userId,
    actorUserId: userId,
    nowUtc: '2026-09-29T10:00:00.000Z',
    draftRevision: 1,
    market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
    lookups: lookupsWith(policy),
    ...overrides,
  };
}

const eur = (minorUnits: number) => ({ minorUnits, currencyCode: 'EUR' });

function validBody(): Record<string, unknown> {
  return {
    title: 'Trekking bike rental in Riga',
    shortDescription: 'Well maintained trekking bikes with helmets included',
    fullDescription:
      'Comfortable trekking bikes for exploring the city and the coast, serviced weekly and fitted on request.',
    categoryId: 'sport',
    subcategoryId: 'cycling',
    categoryConfirmed: true,
    brandModel: 'Trek FX 3',
    mediaRefs: ['media-1', 'media-2'],
    inventoryGroups: [
      {
        id: id('G1'),
        label: 'Frame M',
        quantity: 5,
        condition: 'good',
        sizeOrVariant: 'M',
        includedAccessories: ['helmet'],
        photoRefs: ['media-g1'],
        status: 'available',
      },
    ],
    availability: {
      timeZoneId: 'Europe/Riga',
      coverage: {
        startsAtUtc: '2026-09-29T00:00:00.000Z',
        endsAtUtc: '2026-12-31T00:00:00.000Z',
        confirmedAtUtc: '2026-09-27T10:00:00.000Z',
      },
      blocks: [
        {
          id: id('B1'),
          groupId: id('G1'),
          startsAtUtc: '2026-10-01T08:00:00.000Z',
          endsAtUtc: '2026-10-01T18:00:00.000Z',
          unitsBlocked: 2,
          source: 'manual_external_rental',
          status: 'active',
          revision: 1,
          createdByUserId: userId,
          createdAtUtc: '2026-09-27T10:00:00.000Z',
          updatedAtUtc: '2026-09-27T10:00:00.000Z',
        },
      ],
    },
    handover: {
      pickupPlaceName: 'City bike shop',
      publicAreaLabel: 'Old town',
      publicGeo: { latitude: 56.9496, longitude: 24.1052 },
      publicGeoPrecisionMeters: 500,
      disclosure: 'approximate_area',
      scheduleMode: 'opening_hours',
      openingHours: [
        { id: 'h1', dayOfWeek: 1, openMinute: 540, closeMinute: 1080, closesNextDay: false },
      ],
      deliveryAvailable: false,
    },
    terms: {
      offeredMinMinutes: 60,
      offeredMaxMinutes: 4320,
      minRenterAge: 16,
      idRequiredAtHandover: true,
      safetyNotice: 'Wear a helmet at all times',
      includedAccessoriesConfirmation: true,
    },
    pricing: {
      currencyCode: 'EUR',
      billingUnitMinutes: 60,
      rateSteps: [
        { minUnits: 1, unitPrice: eur(500) },
        { minUnits: 8, unitPrice: eur(400) },
      ],
      billingRounding: 'started_unit',
      deposit: { amount: eur(0), collectionMethod: 'none' },
      damagePolicy: 'The renter pays for damage beyond normal wear',
      cancellationPolicyId: 'flexible-24h',
    },
    fulfillment: { mode: 'external_link', externalBookingUrl: 'https://example.com/book' },
    attestation: {
      policyVersion: 'rental-policy-1',
      acceptedAtUtc: '2026-09-29T09:00:00.000Z',
      acceptedByUserId: userId,
      hasRightToOffer: true,
      listingAccurate: true,
      prohibitedItemsAcknowledged: true,
    },
  };
}

function withChange(change: (body: Record<string, any>) => void): Record<string, unknown> {
  const body = structuredClone(validBody());
  change(body);
  return body;
}

const check = (body: Record<string, unknown>, ctx = context()) => validateRentalBody(body, ctx);

void test('Rental is available with its rule and media extractor', () => {
  const entry = resolveContentType('rental');
  assert.ok(entry);
  assert.equal(isContentTypeAvailable(entry), true);
  assert.equal(entry.validate, validateRentalBody);
  assert.equal(entry.mediaIds, rentalMediaIds);
  assert.equal(rentalDefaultLimits.maxGroups, 50);
});

void test('a complete Rental listing is valid, including delivery and a deposit', () => {
  assert.deepEqual(check(validBody()), []);
  const rich = withChange((b) => {
    b.handover.deliveryAvailable = true;
    b.handover.deliveryRadiusKm = 12.5;
    b.handover.deliveryFee = eur(0);
    b.handover.deliveryTerms = 'Free delivery inside the ring road';
    b.handover.disclosure = 'public_business_address';
    b.handover.publicAddress = 'Grecinieku iela 1, Riga';
    b.handover.publicGeoPrecisionMeters = 20;
    b.pricing.deposit = {
      amount: eur(5000),
      collectionMethod: 'at_handover',
      terms: 'Returned when the bike is back',
    };
    b.pricing.lateReturnPolicy = 'Charged per started hour';
    b.pricing.cancellationPolicyNote = 'Free until 24 hours before pickup';
    b.terms.usageRestrictions = 'Paved and gravel roads only';
    b.inventoryGroups.push({
      id: id('G2'),
      label: 'Frame L',
      quantity: 2,
      condition: 'like_new',
      sizeOrVariant: 'L',
      status: 'paused',
    });
    b.handover.scheduleMode = 'by_arrangement';
    delete b.handover.openingHours;
  });
  assert.deepEqual(check(rich), []);
  assert.deepEqual(rentalMediaIds(rich), ['media-1', 'media-2', 'media-g1']);
  assert.deepEqual(rentalMediaIds({}), []);
});

void test('adjacent blocks do not overlap and exact-capacity blocks are allowed', () => {
  const body = withChange((b) => {
    const base = b.availability.blocks[0];
    b.availability.blocks = [
      { ...base, id: id('B1'), unitsBlocked: 3 },
      {
        ...base,
        id: id('B2'),
        startsAtUtc: base.endsAtUtc,
        endsAtUtc: '2026-10-01T20:00:00.000Z',
        unitsBlocked: 5,
      },
      { ...base, id: id('B3'), unitsBlocked: 2 },
    ];
  });
  assert.deepEqual(check(body), []);
});

void test('cancelled blocks do not count against capacity', () => {
  const body = withChange((b) => {
    const base = b.availability.blocks[0];
    b.availability.blocks = [
      { ...base, id: id('B1'), unitsBlocked: 5 },
      { ...base, id: id('B2'), unitsBlocked: 5, status: 'cancelled' },
    ];
  });
  assert.deepEqual(check(body), []);
});

const invalidCases: ReadonlyArray<readonly [string, (body: Record<string, any>) => void, string]> =
  [
    [
      'unknown field',
      (b) => {
        b.surprise = 1;
      },
      'rental.unknown_field:surprise',
    ],
    [
      'private exact address',
      (b) => {
        b.exactPickupAddress = 'Home 1';
      },
      'rental.private_field_forbidden:exactPickupAddress',
    ],
    [
      'private exact geo nested in handover',
      (b) => {
        b.handover.exactPickupGeo = { latitude: 1, longitude: 2 };
      },
      'rental.private_field_forbidden:exactPickupGeo',
    ],
    [
      'private handover instructions',
      (b) => {
        b.handover.handoverInstructions = 'Ring twice';
      },
      'rental.private_field_forbidden:handoverInstructions',
    ],
    [
      'private notes by group',
      (b) => {
        b.inventoryNotesByGroupId = {};
      },
      'rental.private_field_forbidden:inventoryNotesByGroupId',
    ],
    [
      'private notes by block',
      (b) => {
        b.availabilityNotesByBlockId = {};
      },
      'rental.private_field_forbidden:availabilityNotesByBlockId',
    ],
    [
      'title too short',
      (b) => {
        b.title = 'ab';
      },
      'rental.title_length',
    ],
    [
      'short description too short',
      (b) => {
        b.shortDescription = 'Too short';
      },
      'rental.short_description_length',
    ],
    [
      'full description missing',
      (b) => {
        delete b.fullDescription;
      },
      'rental.full_description_length',
    ],
    [
      'category not confirmed (runtime default)',
      (b) => {
        b.categoryConfirmed = false;
      },
      'rental.category_not_confirmed',
    ],
    [
      'category missing',
      (b) => {
        delete b.categoryId;
      },
      'rental.category_required',
    ],
    [
      'no photos',
      (b) => {
        b.mediaRefs = [];
      },
      'rental.cover_required',
    ],
    [
      'duplicate photo',
      (b) => {
        b.mediaRefs = ['m', 'm'];
      },
      'rental.media_duplicate',
    ],
    [
      'no inventory',
      (b) => {
        b.inventoryGroups = [];
      },
      'rental.inventory_group_count',
    ],
    [
      'group id is a local key',
      (b) => {
        b.inventoryGroups[0].id = 'loc_g';
      },
      'rental.inventory_group_id_invalid',
    ],
    [
      'quantity zero',
      (b) => {
        b.inventoryGroups[0].quantity = 0;
      },
      'rental.inventory_group_quantity',
    ],
    [
      'quantity over 999',
      (b) => {
        b.inventoryGroups[0].quantity = 1000;
      },
      'rental.inventory_group_quantity',
    ],
    [
      'unknown condition',
      (b) => {
        b.inventoryGroups[0].condition = 'broken';
      },
      'rental.inventory_group_condition',
    ],
    [
      'size required by policy',
      (b) => {
        delete b.inventoryGroups[0].sizeOrVariant;
      },
      'rental.inventory_group_size_required',
    ],
    [
      'no available group',
      (b) => {
        b.inventoryGroups[0].status = 'paused';
      },
      'rental.inventory_no_available_group',
    ],
    [
      'duplicate group id',
      (b) => {
        b.inventoryGroups.push(structuredClone(b.inventoryGroups[0]));
      },
      'rental.inventory_group_id_duplicate',
    ],
    [
      'timezone invalid',
      (b) => {
        b.availability.timeZoneId = 'Riga';
      },
      'rental.availability_timezone',
    ],
    [
      'coverage missing (an empty calendar is not availability)',
      (b) => {
        delete b.availability.coverage;
      },
      'rental.coverage_required',
    ],
    [
      'coverage stale',
      (b) => {
        b.availability.coverage.confirmedAtUtc = '2026-09-01T10:00:00.000Z';
      },
      'rental.coverage_stale',
    ],
    [
      'coverage confirmed in the future',
      (b) => {
        b.availability.coverage.confirmedAtUtc = '2026-10-10T10:00:00.000Z';
      },
      'rental.coverage_confirmed_in_future',
    ],
    [
      'coverage interval reversed',
      (b) => {
        b.availability.coverage.endsAtUtc = '2026-09-01T00:00:00.000Z';
      },
      'rental.coverage_invalid',
    ],
    [
      'block for an unknown group',
      (b) => {
        b.availability.blocks[0].groupId = id('G9');
      },
      'rental.availability_block_group_unknown',
    ],
    [
      'block interval reversed',
      (b) => {
        b.availability.blocks[0].endsAtUtc = b.availability.blocks[0].startsAtUtc;
      },
      'rental.availability_block_interval',
    ],
    [
      'block id is a local key',
      (b) => {
        b.availability.blocks[0].id = 'loc_b';
      },
      'rental.availability_block_id_invalid',
    ],
    [
      'block units zero',
      (b) => {
        b.availability.blocks[0].unitsBlocked = 0;
      },
      'rental.availability_block_units',
    ],
    [
      'overlapping blocks exceed capacity',
      (b) => {
        const base = b.availability.blocks[0];
        b.availability.blocks = [
          { ...base, id: id('B1'), unitsBlocked: 3 },
          {
            ...base,
            id: id('B2'),
            startsAtUtc: '2026-10-01T10:00:00.000Z',
            endsAtUtc: '2026-10-01T12:00:00.000Z',
            unitsBlocked: 3,
          },
        ];
      },
      'rental.availability_capacity_exceeded',
    ],
    [
      'a single block above the quantity',
      (b) => {
        b.availability.blocks[0].unitsBlocked = 6;
      },
      'rental.availability_capacity_exceeded',
    ],
    [
      'approximate area with an address',
      (b) => {
        b.handover.publicAddress = 'Home 1';
      },
      'rental.handover_approximate_has_address',
    ],
    [
      'approximate geo too precise',
      (b) => {
        b.handover.publicGeoPrecisionMeters = 50;
      },
      'rental.handover_precision_too_fine',
    ],
    [
      'business address disclosure without an address',
      (b) => {
        b.handover.disclosure = 'public_business_address';
      },
      'rental.handover_public_address_required',
    ],
    [
      'geo out of range',
      (b) => {
        b.handover.publicGeo.latitude = 100;
      },
      'rental.handover_geo',
    ],
    [
      'opening hours mode without hours',
      (b) => {
        b.handover.openingHours = [];
      },
      'rental.handover_hours_required',
    ],
    [
      'invalid opening period',
      (b) => {
        b.handover.openingHours[0].closeMinute = 100;
      },
      'rental.handover_hours_invalid',
    ],
    [
      'overlapping opening periods',
      (b) => {
        b.handover.openingHours = [
          { id: 'a', dayOfWeek: 1, openMinute: 540, closeMinute: 1080, closesNextDay: false },
          { id: 'b', dayOfWeek: 1, openMinute: 600, closeMinute: 700, closesNextDay: false },
        ];
      },
      'rental.handover_hours_overlap',
    ],
    [
      'disabled delivery keeps its fee',
      (b) => {
        b.handover.deliveryFee = eur(0);
      },
      'rental.delivery_not_cleared',
    ],
    [
      'delivery without a radius',
      (b) => {
        b.handover = {
          ...b.handover,
          deliveryAvailable: true,
          deliveryFee: eur(0),
          deliveryTerms: 'Terms',
        };
      },
      'rental.delivery_radius',
    ],
    [
      'delivery radius over the policy bound',
      (b) => {
        b.handover = {
          ...b.handover,
          deliveryAvailable: true,
          deliveryRadiusKm: 500,
          deliveryFee: eur(0),
          deliveryTerms: 'Terms',
        };
      },
      'rental.delivery_radius',
    ],
    [
      'delivery without an explicit fee',
      (b) => {
        b.handover = {
          ...b.handover,
          deliveryAvailable: true,
          deliveryRadiusKm: 5,
          deliveryTerms: 'Terms',
        };
      },
      'rental.delivery_fee_required',
    ],
    [
      'delivery without terms',
      (b) => {
        b.handover = {
          ...b.handover,
          deliveryAvailable: true,
          deliveryRadiusKm: 5,
          deliveryFee: eur(0),
        };
      },
      'rental.delivery_terms_required',
    ],
    [
      'duration min above max',
      (b) => {
        b.terms.offeredMinMinutes = 5000;
      },
      'rental.duration_range_invalid',
    ],
    [
      'duration below the platform minimum',
      (b) => {
        b.terms.offeredMinMinutes = 30;
        b.pricing.billingUnitMinutes = 60;
      },
      'rental.duration_outside_platform_bounds',
    ],
    [
      'duration above 90 days',
      (b) => {
        b.terms.offeredMaxMinutes = 200000;
      },
      'rental.duration_outside_platform_bounds',
    ],
    [
      'renter age required by policy',
      (b) => {
        delete b.terms.minRenterAge;
      },
      'rental.min_renter_age_required',
    ],
    [
      'safety notice required by policy',
      (b) => {
        delete b.terms.safetyNotice;
      },
      'rental.safety_notice_required',
    ],
    [
      'accessories not confirmed',
      (b) => {
        b.terms.includedAccessoriesConfirmation = false;
      },
      'rental.accessories_not_confirmed',
    ],
    [
      'billing unit not allowed',
      (b) => {
        b.pricing.billingUnitMinutes = 30;
      },
      'rental.billing_unit',
    ],
    [
      'billing unit larger than the minimum rental',
      (b) => {
        b.pricing.billingUnitMinutes = 1440;
      },
      'rental.billing_unit_exceeds_min_duration',
    ],
    [
      'unsupported rounding',
      (b) => {
        b.pricing.billingRounding = 'nearest';
      },
      'rental.billing_rounding',
    ],
    [
      'invalid currency',
      (b) => {
        b.pricing.currencyCode = 'EURO';
      },
      'rental.currency_invalid',
    ],
    [
      'no rate steps',
      (b) => {
        b.pricing.rateSteps = [];
      },
      'rental.rate_steps_required',
    ],
    [
      'first step is not 1',
      (b) => {
        b.pricing.rateSteps[0].minUnits = 2;
      },
      'rental.rate_first_step',
    ],
    [
      'thresholds not increasing',
      (b) => {
        b.pricing.rateSteps[1].minUnits = 1;
      },
      'rental.rate_thresholds_not_increasing',
    ],
    [
      'unit price increases with duration',
      (b) => {
        b.pricing.rateSteps[1].unitPrice = eur(900);
      },
      'rental.rate_price_increases',
    ],
    [
      'fractional price',
      (b) => {
        b.pricing.rateSteps[0].unitPrice = eur(4.5);
      },
      'rental.rate_step_invalid',
    ],
    [
      'negative price',
      (b) => {
        b.pricing.rateSteps[0].unitPrice = eur(-1);
      },
      'rental.rate_step_invalid',
    ],
    [
      'mixed currencies in the rate plan',
      (b) => {
        b.pricing.rateSteps[1].unitPrice = { minorUnits: 300, currencyCode: 'USD' };
      },
      'rental.rate_step_currency',
    ],
    [
      'deposit missing',
      (b) => {
        delete b.pricing.deposit;
      },
      'rental.deposit_required',
    ],
    [
      'zero deposit collected somewhere',
      (b) => {
        b.pricing.deposit = { amount: eur(0), collectionMethod: 'at_handover' };
      },
      'rental.deposit_zero_needs_none',
    ],
    [
      'nonzero deposit with method none',
      (b) => {
        b.pricing.deposit = { amount: eur(5000), collectionMethod: 'none', terms: 'x' };
      },
      'rental.deposit_method_required',
    ],
    [
      'nonzero deposit without terms',
      (b) => {
        b.pricing.deposit = { amount: eur(5000), collectionMethod: 'at_handover' };
      },
      'rental.deposit_terms_required',
    ],
    [
      'deposit currency differs from the rate plan',
      (b) => {
        b.pricing.deposit = {
          amount: { minorUnits: 0, currencyCode: 'USD' },
          collectionMethod: 'none',
        };
      },
      'rental.deposit_currency',
    ],
    [
      'damage policy missing',
      (b) => {
        delete b.pricing.damagePolicy;
      },
      'rental.damage_policy_required',
    ],
    [
      'cancellation policy missing',
      (b) => {
        delete b.pricing.cancellationPolicyId;
      },
      'rental.cancellation_policy_required',
    ],
    [
      'http external url',
      (b) => {
        b.fulfillment.externalBookingUrl = 'http://example.com/book';
      },
      'rental.external_url_unsafe',
    ],
    [
      'javascript external url',
      (b) => {
        b.fulfillment.externalBookingUrl = 'javascript:alert(1)';
      },
      'rental.external_url_unsafe',
    ],
    [
      'external url with a fragment',
      (b) => {
        b.fulfillment.externalBookingUrl = 'https://example.com/book#token';
      },
      'rental.external_url_fragment',
    ],
    [
      'in-app contact mode',
      (b) => {
        b.fulfillment.mode = 'contact_host';
      },
      'rental.fulfillment_mode',
    ],
    [
      'attestation missing a confirmation',
      (b) => {
        b.attestation.listingAccurate = false;
      },
      'rental.attestation_incomplete',
    ],
    [
      'attestation accepted by another user',
      (b) => {
        b.attestation.acceptedByUserId = id('ZZ');
      },
      'rental.attestation_user',
    ],
    [
      'stale attestation policy version',
      (b) => {
        b.attestation.policyVersion = 'rental-policy-0';
      },
      'rental.attestation_stale_policy',
    ],
    [
      'attestation accepted in the future',
      (b) => {
        b.attestation.acceptedAtUtc = '2026-10-10T00:00:00.000Z';
      },
      'rental.attestation_time',
    ],
    [
      'unreplaced local media id',
      (b) => {
        b.mediaRefs = ['loc_m'];
      },
      'rental.local_id_unreplaced',
    ],
  ];

for (const [name, change, code] of invalidCases)
  void test(`Rental rejects: ${name}`, () => {
    const issues = check(withChange(change));
    assert.ok(issues.includes(code), `${code} not in ${JSON.stringify(issues)}`);
  });

void test('an unknown or disabled market/category policy fails closed', () => {
  const unknown = context({ lookups: lookupsWith(undefined) });
  assert.ok(check(validBody(), unknown).includes('rental.policy_unavailable'));
  const disabled = context({ lookups: lookupsWith({ ...policy, enabled: false }) });
  assert.ok(check(validBody(), disabled).includes('rental.market_policy_unsupported'));
  const missingAuthority = context({
    lookups: { ...lookupsWith(policy), rentalPolicy: undefined as never },
  });
  assert.ok(check(validBody(), missingAuthority).includes('rental.policy_unavailable'));
});

void test('the pinned policy drives limits instead of widget constants', () => {
  const lenient = context({
    lookups: lookupsWith({
      ...policy,
      requiresSizeOrVariant: false,
      requiresMinRenterAge: false,
      requiresSafetyNotice: false,
      coverageFreshnessDays: 60,
    }),
  });
  const body = withChange((b) => {
    delete b.inventoryGroups[0].sizeOrVariant;
    delete b.terms.minRenterAge;
    delete b.terms.safetyNotice;
    b.availability.coverage.confirmedAtUtc = '2026-08-15T10:00:00.000Z';
  });
  assert.deepEqual(check(body, lenient), []);
  assert.ok(check(body).length > 0);
});

void test('the listing currency is explicit and not tied to the market currency', () => {
  const body = withChange((b) => {
    const usd = (minorUnits: number) => ({ minorUnits, currencyCode: 'USD' });
    b.pricing.currencyCode = 'USD';
    b.pricing.rateSteps = [{ minUnits: 1, unitPrice: usd(500) }];
    b.pricing.deposit = { amount: usd(0), collectionMethod: 'none' };
  });
  assert.deepEqual(check(body), []);
});

void test('a known non-zero rate plan arithmetic bound holds for the largest allowed values', () => {
  const body = withChange((b) => {
    b.pricing.rateSteps = [{ minUnits: 1, unitPrice: eur(Number.MAX_SAFE_INTEGER) }];
  });
  assert.deepEqual(check(body), []);
  const over = withChange((b) => {
    b.pricing.rateSteps = [{ minUnits: 1, unitPrice: eur(Number.MAX_SAFE_INTEGER + 2) }];
  });
  assert.ok(check(over).includes('rental.rate_step_invalid'));
});
