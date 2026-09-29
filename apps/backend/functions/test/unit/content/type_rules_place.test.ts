/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-member-access --
   Mutation table: each case edits a deeply nested clone of a valid JSON body, and
   the rules under test accept arbitrary untyped input by design. */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  contentTypeRegistry,
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import {
  placeMediaIds,
  validatePlaceBody,
} from '../../../src/modules/content/domain/type_rules/place_rules.js';
import type {
  ContentValidationContext,
  ReferenceLookups,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';

const lookups: ReferenceLookups = {
  supportsLocale: (locale) => ['en', 'ru', 'lv'].includes(locale),
  subcategoryApplies: (typeId, categoryId, subcategoryId) =>
    typeId === 'place' && categoryId === 'art_culture_museums' && subcategoryId === 'museum',
  requiredCriteria: () => [],
  pointInServiceArea: (latitude, longitude) =>
    latitude > 56 && latitude < 58 && longitude > 23 && longitude < 25.5,
};

function context(overrides: Partial<ContentValidationContext> = {}): ContentValidationContext {
  return {
    typeId: 'place',
    marketId: 'LV',
    publisherRef: { type: 'user', id: userId as never },
    createdByUserId: userId,
    nowUtc: '2026-09-29T10:00:00.000Z',
    market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
    lookups,
    ...overrides,
  };
}

const period = (overrides: Record<string, unknown> = {}) => ({
  id: 'period-1',
  dayOfWeek: 1,
  openMinute: 600,
  closeMinute: 1140,
  closesNextDay: false,
  ...overrides,
});

function validBody(): Record<string, unknown> {
  return {
    title: 'Vermanes garden greenhouse',
    placeKind: 'managedVenue',
    relationshipToPlace: 'owner',
    shortDescription: 'Historic glass greenhouse in the city centre',
    contentLocale: 'en',
    categoryId: 'art_culture_museums',
    subcategoryId: 'museum',
    location: {
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      formattedAddress: 'Elizabetes iela 1, Riga',
      point: { latitude: 56.9496, longitude: 24.1052 },
      timezoneId: 'Europe/Riga',
      accuracy: 'rooftop',
      pinConfirmed: true,
    },
    hours: { mode: 'regular', weeklyPeriods: [period()], seasons: [], exceptions: [] },
    operationalStatus: { status: 'operating' },
    pricing: { entryType: 'paid', entryPriceFrom: 700, currencyCode: 'EUR' },
    media: { coverImage: { mediaId: 'media-cover' }, gallery: [] },
    provenance: {
      sourceType: 'ownerSubmission',
      submittedByUserId: userId,
      relationshipClaim: 'owner',
      createdAtUtc: '2026-09-29T09:00:00.000Z',
      lastConfirmedAtUtc: '2026-09-29T09:00:00.000Z',
    },
  };
}

function withChange(change: (body: Record<string, any>) => void): Record<string, unknown> {
  const body = structuredClone(validBody());
  change(body);
  return body;
}

const check = (body: Record<string, unknown>, ctx = context()) => validatePlaceBody(body, ctx);

void test('Place is available in the registry with its rule and media extractor', () => {
  const entry = resolveContentType('place');
  assert.ok(entry);
  assert.equal(isContentTypeAvailable(entry), true);
  assert.equal(entry.validate, validatePlaceBody);
  assert.equal(entry.mediaIds, placeMediaIds);
  assert.ok(
    contentTypeRegistry.filter(isContentTypeAvailable).some((item) => item.typeId === 'place'),
  );
});

void test('a complete Place body is valid, including optional sections', () => {
  assert.deepEqual(check(validBody()), []);
  const rich = withChange((body) => {
    body.fullDescription = 'A long description of the greenhouse, its history and the collection.';
    body.languages = ['en', 'lv', 'other'];
    body.tags = ['glass', 'garden'];
    body.location.district = 'Centrs';
    body.location.entranceHint = 'Side gate by the pond';
    body.hours = {
      mode: 'regular',
      weeklyPeriods: [
        period({
          id: 'p1',
          dayOfWeek: 5,
          openMinute: 22 * 60,
          closeMinute: 120,
          closesNextDay: true,
        }),
        period({ id: 'p2', dayOfWeek: 6, openMinute: 600, closeMinute: 1080 }),
      ],
      seasons: [],
      exceptions: [
        { id: 'e1', localDate: '2026-12-25', kind: 'closedAllDay', periods: [] },
        {
          id: 'e2',
          localDate: '2026-12-31',
          kind: 'customHours',
          periods: [period({ id: 'e2p', openMinute: 600, closeMinute: 840 })],
        },
      ],
    };
    body.visitPlanning = {
      recommendedVisitMinutes: 90,
      minimumVisitMinutes: 30,
      allowsShortVisit: true,
      weatherDependent: false,
      arrivalBufferMinutes: 5,
      exitBufferMinutes: 10,
      busyTimeNotes: 'Busy on weekends',
      bestTimeWindows: [
        { dayOfWeek: 2, startMinute: 600, endMinute: 720, reason: 'Quiet mornings' },
      ],
    };
    body.amenityIds = ['wheelchair'];
    body.amenityUnknownIds = ['parking'];
    body.pricing = {
      entryType: 'mixed',
      entryPriceFrom: 500,
      entryPriceTo: 900,
      typicalSpendFrom: 300,
      currencyCode: 'EUR',
      pricingNote: 'Garden is free, greenhouse is ticketed',
      officialPricingUrl: 'https://example.com/tickets',
    };
    body.contacts = {
      website: 'https://example.com',
      phone: '+371 2000 0000',
      email: 'info@example.com',
      bookingUrl: 'https://example.com/visit',
      socialUrls: ['https://facebook.com/greenhouse'],
    };
    body.media = {
      coverImage: { mediaId: 'media-cover', altText: 'Greenhouse' },
      gallery: [{ mediaId: 'media-2' }],
    };
  });
  assert.deepEqual(check(rich), []);
  assert.deepEqual(placeMediaIds(rich), ['media-cover', 'media-2']);
  assert.deepEqual(placeMediaIds({}), []);
});

const invalidCases: ReadonlyArray<readonly [string, (body: Record<string, any>) => void, string]> =
  [
    [
      'unknown top-level field',
      (b) => {
        b.surprise = 1;
      },
      'place.unknown_field:surprise',
    ],
    [
      'short title',
      (b) => {
        b.title = 'A';
      },
      'place.title',
    ],
    [
      'long title',
      (b) => {
        b.title = 'x'.repeat(101);
      },
      'place.title',
    ],
    [
      'title with a phone number',
      (b) => {
        b.title = 'Greenhouse +371 2000 0000';
      },
      'place.title.contact_like',
    ],
    [
      'shouting title',
      (b) => {
        b.title = 'BEST GREENHOUSE';
      },
      'place.title.all_caps',
    ],
    [
      'missing kind',
      (b) => {
        delete b.placeKind;
      },
      'place.placeKind',
    ],
    [
      'bad relationship',
      (b) => {
        b.relationshipToPlace = 'boss';
      },
      'place.relationshipToPlace',
    ],
    [
      'short description too short',
      (b) => {
        b.shortDescription = 'Too short';
      },
      'place.shortDescription',
    ],
    [
      'full description too short',
      (b) => {
        b.fullDescription = 'short';
      },
      'place.fullDescription',
    ],
    [
      'locale missing',
      (b) => {
        delete b.contentLocale;
      },
      'place.contentLocale',
    ],
    [
      'locale unsupported',
      (b) => {
        b.contentLocale = 'de';
      },
      'place.contentLocale.unsupported',
    ],
    [
      'language unsupported',
      (b) => {
        b.languages = ['de'];
      },
      'place.languages.unsupported',
    ],
    [
      'category missing',
      (b) => {
        delete b.categoryId;
      },
      'place.categoryId',
    ],
    [
      'subcategory not applicable to Place',
      (b) => {
        b.subcategoryId = 'concert';
      },
      'place.subcategory.not_applicable',
    ],
    [
      'tags not a list',
      (b) => {
        b.tags = 'glass';
      },
      'place.tags',
    ],
    [
      'criteria not an object',
      (b) => {
        b.criteria = [];
      },
      'place.criteria',
    ],
    [
      'address and label both missing',
      (b) => {
        delete b.location.formattedAddress;
      },
      'place.location.address_or_label_missing',
    ],
    [
      'pin not confirmed',
      (b) => {
        b.location.pinConfirmed = false;
      },
      'place.location.pin_unconfirmed',
    ],
    [
      'bad timezone',
      (b) => {
        b.location.timezoneId = 'Riga';
      },
      'place.location.timezoneId',
    ],
    [
      'bad accuracy',
      (b) => {
        b.location.accuracy = 'guess';
      },
      'place.location.accuracy',
    ],
    [
      'bad country',
      (b) => {
        b.location.countryCode = 'Latvia';
      },
      'place.location.countryCode',
    ],
    [
      'latitude out of range',
      (b) => {
        b.location.point.latitude = 91;
      },
      'place.location.point',
    ],
    [
      'point outside service area',
      (b) => {
        b.location.point = { latitude: 0, longitude: 0 };
      },
      'place.location.outside_service_area',
    ],
    [
      'entrance hint with a phone',
      (b) => {
        b.location.entranceHint = 'Door code call +371 2000 0000';
      },
      'place.location.entranceHint.sensitive',
    ],
    [
      'unknown hours mode',
      (b) => {
        b.hours.mode = 'sometimes';
      },
      'place.hours.mode',
    ],
    [
      'seasonal is Phase 2',
      (b) => {
        b.hours = { mode: 'seasonal', weeklyPeriods: [], seasons: [{}], exceptions: [] };
      },
      'place.hours.mode_unsupported:seasonal',
    ],
    [
      'regular without periods',
      (b) => {
        b.hours.weeklyPeriods = [];
      },
      'place.hours.weekly_required',
    ],
    [
      'close before open without overnight flag',
      (b) => {
        b.hours.weeklyPeriods = [period({ openMinute: 900, closeMinute: 600 })];
      },
      'place.hours.period_invalid',
    ],
    [
      '24/7 written as an overnight period',
      (b) => {
        b.hours.weeklyPeriods = [period({ openMinute: 0, closeMinute: 0, closesNextDay: true })];
      },
      'place.hours.period_invalid',
    ],
    [
      'overlapping periods',
      (b) => {
        b.hours.weeklyPeriods = [
          period({ id: 'a' }),
          period({ id: 'b', openMinute: 700, closeMinute: 800 }),
        ];
      },
      'place.hours.period_overlap',
    ],
    [
      'overnight tail overlaps next morning',
      (b) => {
        b.hours.weeklyPeriods = [
          period({
            id: 'a',
            dayOfWeek: 1,
            openMinute: 1320,
            closeMinute: 180,
            closesNextDay: true,
          }),
          period({ id: 'b', dayOfWeek: 2, openMinute: 120, closeMinute: 600 }),
        ];
      },
      'place.hours.period_overlap',
    ],
    [
      'alwaysOpen with periods',
      (b) => {
        b.hours = { mode: 'alwaysOpen', weeklyPeriods: [period()], seasons: [], exceptions: [] };
      },
      'place.hours.always_open_has_periods',
    ],
    [
      'unknown hours with data',
      (b) => {
        b.hours = { mode: 'unknown', weeklyPeriods: [period()], seasons: [], exceptions: [] };
      },
      'place.hours.unknown_has_data',
    ],
    [
      'exception with a bad date',
      (b) => {
        b.hours.exceptions = [
          { id: 'e', localDate: '2026-02-30', kind: 'closedAllDay', periods: [] },
        ];
      },
      'place.hours.exception_invalid',
    ],
    [
      'duplicate exception date',
      (b) => {
        b.hours.exceptions = [
          { id: 'e1', localDate: '2026-12-25', kind: 'closedAllDay', periods: [] },
          { id: 'e2', localDate: '2026-12-25', kind: 'closedAllDay', periods: [] },
        ];
      },
      'place.hours.exception_duplicate',
    ],
    [
      'closed exception with periods',
      (b) => {
        b.hours.exceptions = [
          { id: 'e', localDate: '2026-12-25', kind: 'closedAllDay', periods: [period()] },
        ];
      },
      'place.hours.exception_closed_has_periods',
    ],
    [
      'custom exception without periods',
      (b) => {
        b.hours.exceptions = [
          { id: 'e', localDate: '2026-12-25', kind: 'customHours', periods: [] },
        ];
      },
      'place.hours.exception_periods',
    ],
    [
      'bad operational status',
      (b) => {
        b.operationalStatus = { status: 'closed' };
      },
      'place.operationalStatus.status',
    ],
    [
      'temporary closure without a start',
      (b) => {
        b.operationalStatus = { status: 'temporarilyClosed' };
      },
      'place.operationalStatus.start_required',
    ],
    [
      'temporary closure ends before it starts',
      (b) => {
        b.operationalStatus = {
          status: 'temporarilyClosed',
          startLocalDate: '2026-10-10',
          endLocalDate: '2026-10-01',
        };
      },
      'place.operationalStatus.end',
    ],
    [
      'operating with closure dates',
      (b) => {
        b.operationalStatus = { status: 'operating', startLocalDate: '2026-10-10' };
      },
      'place.operationalStatus.dates_not_allowed',
    ],
    [
      'recommended visit too short',
      (b) => {
        b.visitPlanning = { recommendedVisitMinutes: 5 };
      },
      'place.visitPlanning.recommendedVisitMinutes',
    ],
    [
      'minimum exceeds recommended',
      (b) => {
        b.visitPlanning = { recommendedVisitMinutes: 30, minimumVisitMinutes: 60 };
      },
      'place.visitPlanning.minimum_exceeds_recommended',
    ],
    [
      'short visit without a minimum',
      (b) => {
        b.visitPlanning = { allowsShortVisit: true };
      },
      'place.visitPlanning.short_visit_needs_minimum',
    ],
    [
      'buffer too large',
      (b) => {
        b.visitPlanning = { arrivalBufferMinutes: 121 };
      },
      'place.visitPlanning.arrivalBufferMinutes',
    ],
    [
      'amenity both known and unknown',
      (b) => {
        b.amenityIds = ['parking'];
        b.amenityUnknownIds = ['parking'];
      },
      'place.amenities.conflict',
    ],
    [
      'wrong currency',
      (b) => {
        b.pricing.currencyCode = 'USD';
      },
      'place.pricing.currencyCode',
    ],
    [
      'floating point price',
      (b) => {
        b.pricing.entryPriceFrom = 7.5;
      },
      'place.pricing.entryPriceFrom',
    ],
    [
      'inverted price range',
      (b) => {
        b.pricing.entryPriceFrom = 900;
        b.pricing.entryPriceTo = 700;
      },
      'place.pricing.entry_range',
    ],
    [
      'paid without a price',
      (b) => {
        delete b.pricing.entryPriceFrom;
      },
      'place.pricing.entryPriceFrom_required',
    ],
    [
      'mixed without a note',
      (b) => {
        b.pricing = { entryType: 'mixed', entryPriceFrom: 500, currencyCode: 'EUR' };
      },
      'place.pricing.note_required',
    ],
    [
      'free with an entry price',
      (b) => {
        b.pricing = { entryType: 'free', entryPriceFrom: 500, currencyCode: 'EUR' };
      },
      'place.pricing.entry_prices_not_cleared',
    ],
    [
      'unsafe pricing url',
      (b) => {
        b.pricing.officialPricingUrl = 'http://example.com';
      },
      'place.pricing.officialPricingUrl',
    ],
    [
      'javascript website',
      (b) => {
        b.contacts = { website: 'javascript:alert(1)' };
      },
      'place.contacts.website',
    ],
    [
      'bad phone',
      (b) => {
        b.contacts = { phone: 'call' };
      },
      'place.contacts.phone',
    ],
    [
      'bad social url',
      (b) => {
        b.contacts = { socialUrls: ['http://x.co'] };
      },
      'place.contacts.socialUrls',
    ],
    [
      'cover missing',
      (b) => {
        delete b.media.coverImage;
      },
      'place.media.cover_missing',
    ],
    [
      'thirteen gallery images',
      (b) => {
        b.media.gallery = Array.from({ length: 13 }, (_, i) => ({ mediaId: `g${i}` }));
      },
      'place.media.gallery_too_large',
    ],
    [
      'duplicate media',
      (b) => {
        b.media.gallery = [{ mediaId: 'media-cover' }];
      },
      'place.media.duplicate',
    ],
    [
      'unreplaced local media id',
      (b) => {
        b.media.coverImage.mediaId = 'loc_cover';
      },
      'place.local_id_unreplaced',
    ],
    [
      'unreplaced local period id',
      (b) => {
        b.hours.weeklyPeriods[0].id = 'loc_p';
      },
      'place.local_id_unreplaced',
    ],
    [
      'provenance author differs from the actor',
      (b) => {
        b.provenance.submittedByUserId = 'someone-else';
      },
      'place.provenance.submittedBy',
    ],
    [
      'provenance claim differs from relationship',
      (b) => {
        b.provenance.relationshipClaim = 'staff';
      },
      'place.provenance.relationshipClaim',
    ],
    [
      'source type not derived from relationship',
      (b) => {
        b.provenance.sourceType = 'staffSubmission';
      },
      'place.provenance.sourceType',
    ],
    [
      'provenance timestamp invalid',
      (b) => {
        b.provenance.lastConfirmedAtUtc = 'yesterday';
      },
      'place.provenance.lastConfirmedAtUtc',
    ],
    [
      'missing provenance',
      (b) => {
        delete b.provenance;
      },
      'place.provenance',
    ],
  ];

for (const [name, change, code] of invalidCases)
  void test(`Place rejects: ${name}`, () => {
    const issues = check(withChange(change));
    assert.ok(issues.includes(code), `${code} not in ${JSON.stringify(issues)}`);
  });

void test('derived source type follows the relationship', () => {
  for (const [relationship, sourceType] of [
    ['owner', 'ownerSubmission'],
    ['staff', 'staffSubmission'],
    ['visitor', 'creatorSubmission'],
    ['curator', 'creatorSubmission'],
  ] as const) {
    const body = withChange((b) => {
      b.relationshipToPlace = relationship;
      b.provenance.relationshipClaim = relationship;
      b.provenance.sourceType = sourceType;
    });
    assert.deepEqual(check(body), [], relationship);
  }
});

void test('an unanswered reference authority fails closed instead of passing', () => {
  const unavailable = context({
    lookups: {
      supportsLocale: () => undefined,
      subcategoryApplies: () => undefined,
      requiredCriteria: () => undefined,
      pointInServiceArea: () => undefined,
    },
  });
  const issues = check(validBody(), unavailable);
  for (const code of [
    'place.contentLocale.registry_unavailable',
    'place.taxonomy_unavailable',
    'place.criteria.registry_unavailable',
    'place.location.service_area_unavailable',
  ])
    assert.ok(issues.includes(code), code);
});

void test('required dynamic criteria of the subcategory profile must be present', () => {
  const needing = context({ lookups: { ...lookups, requiredCriteria: () => ['difficulty'] } });
  assert.ok(check(validBody(), needing).includes('place.criteria.required_missing:difficulty'));
  const provided = withChange((b) => {
    b.criteria = { difficulty: 'easy' };
  });
  assert.deepEqual(check(provided, needing), []);
});

void test('a different market currency is enforced from the pinned MarketConfig', () => {
  const other = context({ market: { currencyCode: 'USD', timezoneId: 'Europe/Riga' } });
  assert.ok(check(validBody(), other).includes('place.pricing.currencyCode'));
});
