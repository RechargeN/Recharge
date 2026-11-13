/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call --
   Mutation table: each case edits a deeply nested clone of a valid JSON body, and
   the rules under test accept arbitrary untyped input by design. */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import {
  eventArchetypes,
  eventMediaIds,
  eventRuleConfig,
  participationModes,
  resolveLocalTime,
  validateEventBody,
} from '../../../src/modules/content/domain/type_rules/event_rules.js';
import type {
  ContentValidationContext,
  ReferenceLookups,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';

const lookups: ReferenceLookups = {
  supportsLocale: () => true,
  subcategoryApplies: (typeId, categoryId, subcategoryId) =>
    typeId === 'event' && categoryId === 'workshops_masterclasses' && subcategoryId === 'pottery',
  requiredCriteria: () => [],
  pointInServiceArea: () => true,
};

function context(overrides: Partial<ContentValidationContext> = {}): ContentValidationContext {
  return {
    typeId: 'event',
    marketId: 'LV',
    publisherRef: { type: 'user', id: userId as never },
    createdByUserId: userId,
    actorUserId: userId,
    nowUtc: '2026-09-29T10:00:00.000Z',
    draftRevision: 1,
    market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
    lookups,
    ...overrides,
  };
}

const slotId = (n: number) => `018FQ2Z8Q9N4M7K2T6V3W1XS${String(n).padStart(2, '0')}`.slice(0, 26);
const slot = (n: number, localDate: string, startAtUtc: string, endAtUtc: string) => ({
  id: slotId(n),
  localDate,
  startAtUtc,
  endAtUtc,
});

function baseSchedule(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    timezoneId: 'Europe/Riga',
    scheduleMode: 'oneTime',
    allDay: false,
    localStartDate: '2026-10-10',
    startMinute: 1080,
    durationMinutes: 120,
    allowsPartialAttendance: false,
    bufferBeforeMinutes: 0,
    bufferAfterMinutes: 0,
    ...overrides,
  };
}

function validBody(): Record<string, unknown> {
  return {
    eventArchetype: 'workshop',
    primaryParticipationMode: 'learn',
    additionalParticipationModes: ['create'],
    title: 'Ceramics evening',
    categoryId: 'workshops_masterclasses',
    subcategoryId: 'pottery',
    shortDescription: 'Shape your own bowl on the wheel',
    fullDescription:
      'An evening of guided pottery in a friendly studio. All materials and firing are included.',
    media: {
      coverImage: { mediaId: 'media-cover', altText: 'A potter shaping a bowl' },
      gallery: [],
      rightsConfirmed: true,
    },
    format: 'offline',
    location: {
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      formattedAddress: 'Brivibas iela 1, Riga',
      latitude: 56.95,
      longitude: 24.1,
      pinConfirmed: true,
    },
    schedule: baseSchedule(),
    eventSlots: [slot(1, '2026-10-10', '2026-10-10T15:00:00.000Z', '2026-10-10T17:00:00.000Z')],
    pricing: { mode: 'free', paymentCollectionMode: 'none' },
    participants: { capacityMode: 'unknown' },
    registration: { mode: 'none' },
    visibility: 'public',
  };
}

function withChange(change: (body: Record<string, any>) => void): Record<string, unknown> {
  const body = structuredClone(validBody());
  change(body);
  return body;
}

const check = (body: Record<string, unknown>, ctx = context()) => validateEventBody(body, ctx);

void test('Event is available with its rule and media extractor', () => {
  const entry = resolveContentType('event');
  assert.ok(entry);
  assert.equal(isContentTypeAvailable(entry), true);
  assert.equal(entry.validate, validateEventBody);
  assert.equal(entry.mediaIds, eventMediaIds);
  assert.equal(eventArchetypes.length, 34);
  assert.equal(new Set(eventArchetypes).size, 34);
  assert.equal(participationModes.length, 17);
  assert.equal(eventRuleConfig.maxRecurringProjection, 180);
});

void test('a complete one-time Event is valid, including optional sections', () => {
  assert.deepEqual(check(validBody()), []);
  const rich = withChange((b) => {
    b.tags = ['clay', 'crafts'];
    b.criteria = { level: 'beginner' };
    b.media.gallery = [{ mediaId: 'g1', altText: 'The studio' }];
    b.audience = {
      ageMin: 12,
      ageMax: 99,
      familyFriendly: true,
      kidsAllowed: true,
      petFriendly: false,
      wheelchairAccessible: true,
    };
    b.amenityIds = ['wheelchair', 'parking'];
    b.location.venueName = 'Clay House';
    b.location.accuracy = 'rooftop';
    b.pricing = {
      mode: 'fixed',
      price: { amountMinor: 2500, currencyCode: 'EUR' },
      pricingModel: 'per_person',
      paymentCollectionMode: 'onsite',
    };
    b.participants = { capacityMode: 'known', capacity: 12, minParticipants: 4 };
    b.registration = { mode: 'external', externalBookingUrl: 'https://example.com/register' };
    b.visibility = 'unlisted';
    b.schedule = baseSchedule({
      allowsPartialAttendance: true,
      minimumVisitDurationMinutes: 60,
      bufferBeforeMinutes: 15,
    });
  });
  assert.deepEqual(check(rich), []);
  assert.deepEqual(eventMediaIds(rich), ['media-cover', 'g1']);
  assert.deepEqual(eventMediaIds({}), []);
});

void test('every archetype and participation mode is accepted as an explicit choice', () => {
  for (const archetype of eventArchetypes) {
    const body = withChange((b) => {
      b.eventArchetype = archetype;
      if (archetype === 'other')
        b.eventArchetypeOtherReason = 'Something that fits no listed mechanic';
    });
    assert.deepEqual(check(body), [], archetype);
  }
  for (const mode of participationModes) {
    const body = withChange((b) => {
      b.primaryParticipationMode = mode;
      b.additionalParticipationModes = [];
    });
    assert.deepEqual(check(body), [], mode);
  }
});

void test('the archetype is never derived from the category or title', () => {
  const categories: ReadonlyArray<readonly [string, string]> = [
    ['workshops_masterclasses', 'pottery'],
    ['music', 'concert'],
    ['sport', 'football'],
  ];
  for (const [categoryId, subcategoryId] of categories) {
    const body = withChange((b) => {
      delete b.eventArchetype;
      b.categoryId = categoryId;
      b.subcategoryId = subcategoryId;
      b.title = 'Concert of the season';
    });
    const open = context({
      lookups: { ...lookups, subcategoryApplies: () => true },
    });
    assert.ok(check(body, open).includes('event.eventArchetype'), categoryId);
  }
});

// --- Local time resolution around DST (Europe/Riga: EET +2, EEST +3) --------

void test('regular local times resolve with the zone offset', () => {
  const summer = resolveLocalTime(
    'Europe/Riga',
    '2026-07-01',
    720,
    'shiftForward',
    'earlierOffset',
  );
  assert.equal(
    summer === 'gap_rejected' ? '' : new Date(summer.utcMs).toISOString(),
    '2026-07-01T09:00:00.000Z',
  );
  const winter = resolveLocalTime(
    'Europe/Riga',
    '2026-01-15',
    720,
    'shiftForward',
    'earlierOffset',
  );
  assert.equal(
    winter === 'gap_rejected' ? '' : new Date(winter.utcMs).toISOString(),
    '2026-01-15T10:00:00.000Z',
  );
});

void test('a skipped local time is shifted forward or rejected by policy', () => {
  // 2026-03-29 03:00 -> 04:00: local 03:30 does not exist.
  const shifted = resolveLocalTime(
    'Europe/Riga',
    '2026-03-29',
    210,
    'shiftForward',
    'earlierOffset',
  );
  assert.notEqual(shifted, 'gap_rejected');
  if (shifted !== 'gap_rejected') {
    assert.equal(new Date(shifted.utcMs).toISOString(), '2026-03-29T01:30:00.000Z');
    assert.equal(shifted.shifted, true);
  }
  assert.equal(
    resolveLocalTime('Europe/Riga', '2026-03-29', 210, 'reject', 'earlierOffset'),
    'gap_rejected',
  );
});

void test('an ambiguous local time takes the earlier or later offset by policy', () => {
  // 2026-10-25 04:00 EEST -> 03:00 EET: local 03:30 happens twice.
  const earlier = resolveLocalTime(
    'Europe/Riga',
    '2026-10-25',
    210,
    'shiftForward',
    'earlierOffset',
  );
  const later = resolveLocalTime('Europe/Riga', '2026-10-25', 210, 'shiftForward', 'laterOffset');
  assert.notEqual(earlier, 'gap_rejected');
  assert.notEqual(later, 'gap_rejected');
  if (earlier !== 'gap_rejected' && later !== 'gap_rejected') {
    assert.equal(new Date(earlier.utcMs).toISOString(), '2026-10-25T00:30:00.000Z');
    assert.equal(new Date(later.utcMs).toISOString(), '2026-10-25T01:30:00.000Z');
  }
});

// --- Schedules ---------------------------------------------------------------

void test('an all-day multi-day event spans local midnights', () => {
  const body = withChange((b) => {
    b.schedule = baseSchedule({ allDay: true, startMinute: 0, durationMinutes: 2880 });
    b.eventSlots = [slot(1, '2026-10-10', '2026-10-09T21:00:00.000Z', '2026-10-11T21:00:00.000Z')];
  });
  assert.deepEqual(check(body), []);
});

void test('a multi-date event materializes every date across a DST change', () => {
  const body = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'multiDate',
      multiDateLocalDates: ['2026-10-10', '2026-10-26'],
    });
    b.eventSlots = [
      slot(1, '2026-10-10', '2026-10-10T15:00:00.000Z', '2026-10-10T17:00:00.000Z'),
      slot(2, '2026-10-26', '2026-10-26T16:00:00.000Z', '2026-10-26T18:00:00.000Z'),
    ];
  });
  assert.deepEqual(check(body), []);
  const missing = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'multiDate',
      multiDateLocalDates: ['2026-10-10', '2026-10-26'],
    });
  });
  assert.ok(check(missing).includes('event.occurrences_mismatch'));
});

const weekly = (overrides: Record<string, unknown> = {}) => ({
  frequency: 'weekly',
  interval: 1,
  weekdays: [1, 3],
  endMode: 'never',
  exceptionLocalDates: [],
  dstGapPolicy: 'shiftForward',
  dstOverlapPolicy: 'earlierOffset',
  ...overrides,
});

const weeklySlots = [
  slot(1, '2026-10-05', '2026-10-05T15:00:00.000Z', '2026-10-05T17:00:00.000Z'),
  slot(2, '2026-10-07', '2026-10-07T15:00:00.000Z', '2026-10-07T17:00:00.000Z'),
  slot(3, '2026-10-12', '2026-10-12T15:00:00.000Z', '2026-10-12T17:00:00.000Z'),
  slot(4, '2026-10-14', '2026-10-14T15:00:00.000Z', '2026-10-14T17:00:00.000Z'),
  slot(5, '2026-10-19', '2026-10-19T15:00:00.000Z', '2026-10-19T17:00:00.000Z'),
];

void test('a weekly series is a leading run of its deterministic expansion', () => {
  const body = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-10-05',
      recurrence: weekly(),
    });
    b.eventSlots = weeklySlots;
  });
  assert.deepEqual(check(body), []);
  // Fewer slots are a shorter rolling projection and stay valid.
  assert.deepEqual(
    check(
      withChange((b) => {
        b.schedule = baseSchedule({
          scheduleMode: 'recurring',
          localStartDate: '2026-10-05',
          recurrence: weekly(),
        });
        b.eventSlots = weeklySlots.slice(0, 2);
      }),
    ),
    [],
  );
  // Skipping a date is not a leading run.
  const skipped = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-10-05',
      recurrence: weekly(),
    });
    b.eventSlots = [weeklySlots[0], weeklySlots[2]];
  });
  assert.ok(check(skipped).includes('event.occurrences_mismatch'));
});

void test('exception dates are excluded from the series', () => {
  const rule = weekly({ exceptionLocalDates: ['2026-10-07'] });
  const body = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-10-05',
      recurrence: rule,
    });
    b.eventSlots = [weeklySlots[0], weeklySlots[2], weeklySlots[3]];
  });
  assert.deepEqual(check(body), []);
  const includesException = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-10-05',
      recurrence: rule,
    });
    b.eventSlots = weeklySlots.slice(0, 3);
  });
  assert.ok(check(includesException).includes('event.occurrences_mismatch'));
});

void test('monthly series honour the day policy at month ends', () => {
  const winterNow = context({ nowUtc: '2026-01-01T00:00:00.000Z' });
  const monthly = (policy: string) => ({
    frequency: 'monthly',
    interval: 1,
    monthlyDayPolicy: policy,
    endMode: 'occurrenceCount',
    occurrenceCount: 3,
    exceptionLocalDates: [],
    dstGapPolicy: 'shiftForward',
    dstOverlapPolicy: 'earlierOffset',
  });
  const useLast = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-01-31',
      startMinute: 600,
      recurrence: monthly('useLastDay'),
    });
    b.eventSlots = [
      slot(1, '2026-01-31', '2026-01-31T08:00:00.000Z', '2026-01-31T10:00:00.000Z'),
      slot(2, '2026-02-28', '2026-02-28T08:00:00.000Z', '2026-02-28T10:00:00.000Z'),
      slot(3, '2026-03-31', '2026-03-31T07:00:00.000Z', '2026-03-31T09:00:00.000Z'),
    ];
  });
  assert.deepEqual(check(useLast, winterNow), []);
  const skip = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-01-31',
      startMinute: 600,
      recurrence: monthly('skipInvalidDate'),
    });
    b.eventSlots = [
      slot(1, '2026-01-31', '2026-01-31T08:00:00.000Z', '2026-01-31T10:00:00.000Z'),
      slot(2, '2026-03-31', '2026-03-31T07:00:00.000Z', '2026-03-31T09:00:00.000Z'),
      slot(3, '2026-05-31', '2026-05-31T07:00:00.000Z', '2026-05-31T09:00:00.000Z'),
    ];
  });
  assert.deepEqual(check(skip, winterNow), []);
});

void test('daily and yearly series expand deterministically', () => {
  const daily = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-10-10',
      recurrence: {
        frequency: 'daily',
        interval: 2,
        endMode: 'untilDate',
        untilLocalDate: '2026-10-14',
        exceptionLocalDates: [],
        dstGapPolicy: 'shiftForward',
        dstOverlapPolicy: 'earlierOffset',
      },
    });
    b.eventSlots = [
      slot(1, '2026-10-10', '2026-10-10T15:00:00.000Z', '2026-10-10T17:00:00.000Z'),
      slot(2, '2026-10-12', '2026-10-12T15:00:00.000Z', '2026-10-12T17:00:00.000Z'),
      slot(3, '2026-10-14', '2026-10-14T15:00:00.000Z', '2026-10-14T17:00:00.000Z'),
    ];
  });
  assert.deepEqual(check(daily), []);
  const yearly = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-12-25',
      startMinute: 600,
      recurrence: {
        frequency: 'yearly',
        interval: 1,
        endMode: 'occurrenceCount',
        occurrenceCount: 2,
        exceptionLocalDates: [],
        dstGapPolicy: 'shiftForward',
        dstOverlapPolicy: 'earlierOffset',
      },
    });
    b.eventSlots = [
      slot(1, '2026-12-25', '2026-12-25T08:00:00.000Z', '2026-12-25T10:00:00.000Z'),
      slot(2, '2027-12-25', '2027-12-25T08:00:00.000Z', '2027-12-25T10:00:00.000Z'),
    ];
  });
  assert.deepEqual(check(yearly), []);
});

void test('a series that lands on a skipped local time follows the saved DST policy', () => {
  const rule = (gap: string) => ({
    frequency: 'daily',
    interval: 1,
    endMode: 'occurrenceCount',
    occurrenceCount: 1,
    exceptionLocalDates: [],
    dstGapPolicy: gap,
    dstOverlapPolicy: 'earlierOffset',
  });
  const nowBefore = context({ nowUtc: '2026-03-01T00:00:00.000Z' });
  const shifted = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-03-29',
      startMinute: 210,
      recurrence: rule('shiftForward'),
    });
    b.eventSlots = [slot(1, '2026-03-29', '2026-03-29T01:30:00.000Z', '2026-03-29T03:30:00.000Z')];
  });
  assert.deepEqual(check(shifted, nowBefore), []);
  const rejected = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-03-29',
      startMinute: 210,
      recurrence: rule('reject'),
    });
    b.eventSlots = shifted.eventSlots as never;
  });
  assert.ok(check(rejected, nowBefore).includes('event.dst_gap_rejected'));
});

const invalidCases: ReadonlyArray<readonly [string, (body: Record<string, any>) => void, string]> =
  [
    [
      'unknown field',
      (b) => {
        b.surprise = 1;
      },
      'event.unknown_field:surprise',
    ],
    [
      'missing archetype',
      (b) => {
        delete b.eventArchetype;
      },
      'event.eventArchetype',
    ],
    [
      'unknown archetype',
      (b) => {
        b.eventArchetype = 'rave';
      },
      'event.eventArchetype',
    ],
    [
      'other archetype without a reason',
      (b) => {
        b.eventArchetype = 'other';
      },
      'event.archetype_other_reason',
    ],
    [
      'reason without the other archetype',
      (b) => {
        b.eventArchetypeOtherReason = 'because';
      },
      'event.archetype_reason_without_other',
    ],
    [
      'missing primary participation',
      (b) => {
        delete b.primaryParticipationMode;
      },
      'event.primaryParticipationMode',
    ],
    [
      'four additional participation modes',
      (b) => {
        b.additionalParticipationModes = ['create', 'watch', 'play', 'shop'];
      },
      'event.additional_participation_limit',
    ],
    [
      'primary repeated as additional',
      (b) => {
        b.additionalParticipationModes = ['learn'];
      },
      'event.participation_mode_duplicate',
    ],
    [
      'duplicate additional mode',
      (b) => {
        b.additionalParticipationModes = ['create', 'create'];
      },
      'event.participation_mode_duplicate',
    ],
    [
      'unknown participation mode',
      (b) => {
        b.additionalParticipationModes = ['dance'];
      },
      'event.additionalParticipationModes',
    ],
    [
      'short title',
      (b) => {
        b.title = 'Hi';
      },
      'event.title_length',
    ],
    [
      'short description too short',
      (b) => {
        b.shortDescription = 'Short';
      },
      'event.short_description_length',
    ],
    [
      'full description too short',
      (b) => {
        b.fullDescription = 'Short';
      },
      'event.full_description_length',
    ],
    [
      'too many tags',
      (b) => {
        b.tags = Array.from({ length: 11 }, (_, i) => `t${i}`);
      },
      'event.tags',
    ],
    [
      'subcategory not applicable to Event',
      (b) => {
        b.subcategoryId = 'ballet';
      },
      'event.subcategory_not_applicable',
    ],
    [
      'cover missing',
      (b) => {
        delete b.media.coverImage;
      },
      'event.cover_required',
    ],
    [
      'cover alt text missing',
      (b) => {
        delete b.media.coverImage.altText;
      },
      'event.alt_text_required',
    ],
    [
      'rights not confirmed',
      (b) => {
        b.media.rightsConfirmed = false;
      },
      'event.media_rights_required',
    ],
    [
      'gallery item without alt text',
      (b) => {
        b.media.gallery = [{ mediaId: 'g1' }];
      },
      'event.alt_text_required',
    ],
    [
      'unreplaced local media id',
      (b) => {
        b.media.coverImage.mediaId = 'loc_cover';
      },
      'event.local_id_unreplaced',
    ],
    [
      'unknown format',
      (b) => {
        b.format = 'virtual';
      },
      'event.format',
    ],
    [
      'offline with online access',
      (b) => {
        b.onlineAccessMode = 'publicLink';
        b.publicOnlineUrl = 'https://example.com/live';
      },
      'event.online_access_not_allowed',
    ],
    [
      'online without an access mode',
      (b) => {
        b.format = 'online';
        b.location = { marketCityId: 'riga', countryCode: 'LV' };
      },
      'event.online_access_required',
    ],
    [
      'public link that is not https',
      (b) => {
        b.format = 'online';
        b.location = { marketCityId: 'riga', countryCode: 'LV' };
        b.onlineAccessMode = 'publicLink';
        b.publicOnlineUrl = 'http://example.com';
      },
      'event.public_online_url_invalid',
    ],
    [
      'online event with a physical pin',
      (b) => {
        b.format = 'online';
        b.onlineAccessMode = 'publicLink';
        b.publicOnlineUrl = 'https://example.com/live';
      },
      'event.online_has_physical_location',
    ],
    [
      'external online access needs external registration',
      (b) => {
        b.format = 'online';
        b.location = { marketCityId: 'riga', countryCode: 'LV' };
        b.onlineAccessMode = 'externalRegistration';
      },
      'event.online_access_registration_conflict',
    ],
    [
      'offline city missing',
      (b) => {
        delete b.location.city;
      },
      'event.city_required',
    ],
    [
      'offline address and meeting point missing',
      (b) => {
        delete b.location.formattedAddress;
      },
      'event.location_required',
    ],
    [
      'offline pin not confirmed',
      (b) => {
        b.location.pinConfirmed = false;
      },
      'event.location_pin_unconfirmed',
    ],
    [
      'offline coordinates missing',
      (b) => {
        delete b.location.latitude;
      },
      'event.location_coordinates_required',
    ],
    [
      'market city missing',
      (b) => {
        delete b.location.marketCityId;
      },
      'event.market_city_required',
    ],
    [
      'timezone invalid',
      (b) => {
        b.schedule.timezoneId = 'Riga';
      },
      'event.timezone_required',
    ],
    [
      'duration not positive',
      (b) => {
        b.schedule.durationMinutes = 0;
      },
      'event.duration_invalid',
    ],
    [
      'local start date invalid',
      (b) => {
        b.schedule.localStartDate = '2026-02-30';
      },
      'event.local_start_date_invalid',
    ],
    [
      'start minute out of range',
      (b) => {
        b.schedule.startMinute = 1440;
      },
      'event.start_minute_invalid',
    ],
    [
      'all-day duration not whole days',
      (b) => {
        b.schedule.allDay = true;
        b.schedule.durationMinutes = 100;
      },
      'event.all_day_duration_invalid',
    ],
    [
      'unknown schedule mode',
      (b) => {
        b.schedule.scheduleMode = 'sometimes';
      },
      'event.schedule_mode',
    ],
    [
      'multi-date without dates',
      (b) => {
        b.schedule.scheduleMode = 'multiDate';
      },
      'event.multi_dates_invalid',
    ],
    [
      'duplicate multi-dates',
      (b) => {
        b.schedule.scheduleMode = 'multiDate';
        b.schedule.multiDateLocalDates = ['2026-10-10', '2026-10-10'];
      },
      'event.multi_date_duplicate',
    ],
    [
      'dates on a one-time event',
      (b) => {
        b.schedule.multiDateLocalDates = ['2026-10-10'];
      },
      'event.multi_dates_not_allowed',
    ],
    [
      'recurrence on a one-time event',
      (b) => {
        b.schedule.recurrence = weekly();
      },
      'event.recurrence_not_allowed',
    ],
    [
      'recurring without a rule',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
      },
      'event.recurrence_invalid',
    ],
    [
      'weekly without weekdays',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ weekdays: [] });
      },
      'event.recurrence_weekdays',
    ],
    [
      'weekday out of range',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ weekdays: [8] });
      },
      'event.recurrence_weekdays',
    ],
    [
      'interval zero',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ interval: 0 });
      },
      'event.recurrence_interval',
    ],
    [
      'never with an end date',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ untilLocalDate: '2026-12-01' });
      },
      'event.recurrence_end_fields',
    ],
    [
      'until date before the start',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ endMode: 'untilDate', untilLocalDate: '2026-01-01' });
      },
      'event.recurrence_until_before_start',
    ],
    [
      'occurrence count missing',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ endMode: 'occurrenceCount' });
      },
      'event.recurrence_count_required',
    ],
    [
      'weekdays on a monthly rule',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ frequency: 'monthly', monthlyDayPolicy: 'useLastDay' });
      },
      'event.recurrence_weekdays_not_allowed',
    ],
    [
      'monthly without a day policy',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ frequency: 'monthly', weekdays: undefined });
      },
      'event.monthly_day_policy',
    ],
    [
      'ordinal weekday recurrence is outside the subset',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ bySetPositions: [1] });
      },
      'event.recurrence.unknown_field:bySetPositions',
    ],
    [
      'bad exception date',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ exceptionLocalDates: ['nope'] });
      },
      'event.recurrence_exception_invalid',
    ],
    [
      'unknown DST gap policy',
      (b) => {
        b.schedule.scheduleMode = 'recurring';
        b.schedule.recurrence = weekly({ dstGapPolicy: 'ignore' });
      },
      'event.dst_gap_policy',
    ],
    [
      'partial attendance without a minimum',
      (b) => {
        b.schedule.allowsPartialAttendance = true;
      },
      'event.minimum_visit_duration_required',
    ],
    [
      'minimum visit above the duration',
      (b) => {
        b.schedule.allowsPartialAttendance = true;
        b.schedule.minimumVisitDurationMinutes = 500;
      },
      'event.minimum_visit_exceeds_duration',
    ],
    [
      'minimum visit kept after disabling partial attendance',
      (b) => {
        b.schedule.minimumVisitDurationMinutes = 30;
      },
      'event.minimum_visit_not_cleared',
    ],
    [
      'negative buffer',
      (b) => {
        b.schedule.bufferBeforeMinutes = -5;
      },
      'event.bufferBeforeMinutes',
    ],
    [
      'no occurrences',
      (b) => {
        b.eventSlots = [];
      },
      'event.occurrences_required',
    ],
    [
      'occurrence id is a local key',
      (b) => {
        b.eventSlots[0].id = 'loc_occ_1';
      },
      'event.occurrence_invalid',
    ],
    [
      'occurrence ends before it starts',
      (b) => {
        b.eventSlots[0].endAtUtc = '2026-10-10T14:00:00.000Z';
      },
      'event.occurrence_invalid',
    ],
    [
      'occurrence in the past',
      (b) => {
        b.schedule.localStartDate = '2026-01-10';
        b.eventSlots = [
          slot(1, '2026-01-10', '2026-01-10T16:00:00.000Z', '2026-01-10T18:00:00.000Z'),
        ];
      },
      'event.future_occurrence_required',
    ],
    [
      'occurrence time does not match the schedule',
      (b) => {
        b.eventSlots[0].startAtUtc = '2026-10-10T16:00:00.000Z';
        b.eventSlots[0].endAtUtc = '2026-10-10T18:00:00.000Z';
      },
      'event.occurrences_mismatch',
    ],
    [
      'one-time event with two occurrences',
      (b) => {
        b.eventSlots.push(
          slot(2, '2026-10-11', '2026-10-11T15:00:00.000Z', '2026-10-11T17:00:00.000Z'),
        );
      },
      'event.occurrences_mismatch',
    ],
    [
      'audience age range inverted',
      (b) => {
        b.audience = { ageMin: 30, ageMax: 20 };
      },
      'event.age_range_invalid',
    ],
    [
      'kids allowed for an adults-only audience',
      (b) => {
        b.audience = { ageMin: 18, kidsAllowed: true };
      },
      'event.audience_kids_conflict',
    ],
    [
      'duplicate amenity',
      (b) => {
        b.amenityIds = ['a', 'a'];
      },
      'event.amenityIds_duplicate',
    ],
    [
      'unknown pricing mode',
      (b) => {
        b.pricing.mode = 'pwyw';
      },
      'event.pricing_mode',
    ],
    [
      'free event with a price',
      (b) => {
        b.pricing.price = { amountMinor: 100, currencyCode: 'EUR' };
      },
      'event.free_price_conflict',
    ],
    [
      'free event collecting payment',
      (b) => {
        b.pricing.paymentCollectionMode = 'onsite';
      },
      'event.free_price_conflict',
    ],
    [
      'fixed price missing',
      (b) => {
        b.pricing = { mode: 'fixed', pricingModel: 'per_person', paymentCollectionMode: 'onsite' };
      },
      'event.fixed_price_required',
    ],
    [
      'fixed price fractional',
      (b) => {
        b.pricing = {
          mode: 'fixed',
          price: { amountMinor: 1.5, currencyCode: 'EUR' },
          pricingModel: 'per_person',
          paymentCollectionMode: 'onsite',
        };
      },
      'event.fixed_price_required',
    ],
    [
      'fixed price in another currency',
      (b) => {
        b.pricing = {
          mode: 'fixed',
          price: { amountMinor: 100, currencyCode: 'USD' },
          pricingModel: 'per_person',
          paymentCollectionMode: 'onsite',
        };
      },
      'event.price_currency',
    ],
    [
      'fixed price without a pricing model',
      (b) => {
        b.pricing = {
          mode: 'fixed',
          price: { amountMinor: 100, currencyCode: 'EUR' },
          paymentCollectionMode: 'onsite',
        };
      },
      'event.pricing_model',
    ],
    [
      'fixed price with no payment collection',
      (b) => {
        b.pricing = {
          mode: 'fixed',
          price: { amountMinor: 100, currencyCode: 'EUR' },
          pricingModel: 'per_person',
          paymentCollectionMode: 'none',
        };
      },
      'event.payment_mode_unavailable',
    ],
    [
      'external payment without a url',
      (b) => {
        b.pricing = {
          mode: 'fixed',
          price: { amountMinor: 100, currencyCode: 'EUR' },
          pricingModel: 'per_person',
          paymentCollectionMode: 'external',
        };
      },
      'event.external_payment_url_invalid',
    ],
    [
      'payment url without external collection',
      (b) => {
        b.pricing = {
          mode: 'fixed',
          price: { amountMinor: 100, currencyCode: 'EUR' },
          pricingModel: 'per_person',
          paymentCollectionMode: 'onsite',
          externalPaymentUrl: 'https://example.com/pay',
        };
      },
      'event.payment_url_without_external',
    ],
    [
      'known capacity without a number',
      (b) => {
        b.participants = { capacityMode: 'known' };
      },
      'event.capacity_required',
    ],
    [
      'unknown capacity that carries a number',
      (b) => {
        b.participants = { capacityMode: 'unknown', capacity: 10 };
      },
      'event.capacity_not_allowed',
    ],
    [
      'minimum above capacity',
      (b) => {
        b.participants = { capacityMode: 'known', capacity: 5, minParticipants: 9 };
      },
      'event.min_exceeds_capacity',
    ],
    [
      'external registration without a url',
      (b) => {
        b.registration = { mode: 'external' };
      },
      'event.external_booking_url_invalid',
    ],
    [
      'registration url without external registration',
      (b) => {
        b.registration = { mode: 'none', externalBookingUrl: 'https://example.com' };
      },
      'event.booking_url_without_registration',
    ],
    [
      'registration missing',
      (b) => {
        delete b.registration;
      },
      'event.registration_required',
    ],
    [
      'bad visibility',
      (b) => {
        b.visibility = 'secret';
      },
      'event.visibility',
    ],
  ];

for (const [name, change, code] of invalidCases)
  void test(`Event rejects: ${name}`, () => {
    const issues = check(withChange(change));
    assert.ok(issues.includes(code), `${code} not in ${JSON.stringify(issues)}`);
  });

const unsupported: ReadonlyArray<readonly [string, (body: Record<string, any>) => void, string]> = [
  [
    // E2.0: internal registration is accepted only with all its terms; a bare
    // mode is refused by name (see event_rules_internal_registration.test.ts).
    'internal registration without its terms',
    (b) => {
      b.registration = { mode: 'internal' };
    },
    'event.internal_registration.party_size_invalid',
  ],
  [
    'private visibility',
    (b) => {
      b.visibility = 'private';
    },
    'event.unsupported_capability:visibility.private',
  ],
  [
    'ticket types pricing',
    (b) => {
      b.pricing = { mode: 'ticketTypes' };
    },
    'event.unsupported_capability:pricing.ticketTypes',
  ],
  [
    'donation pricing',
    (b) => {
      b.pricing = { mode: 'donation' };
    },
    'event.unsupported_capability:pricing.donation',
  ],
  [
    'internal payments',
    (b) => {
      b.pricing = { mode: 'fixed', paymentCollectionMode: 'internal' };
    },
    'event.unsupported_capability:paymentCollectionMode.internal',
  ],
  [
    'access after internal booking',
    (b) => {
      b.format = 'online';
      b.location = { marketCityId: 'riga', countryCode: 'LV' };
      b.onlineAccessMode = 'internalBooking';
    },
    'event.unsupported_capability:onlineAccessMode.internalBooking',
  ],
  ...[
    'admissionMode',
    'confirmationMode',
    'eligibilityRules',
    'guestPolicy',
    'waitlistPolicy',
    'inventoryAuthority',
    'inventoryPools',
    'ticketTypes',
    'occurrenceOverrides',
    'registrationDeadlineRule',
    'accessPolicy',
    'protectedOnlineAccessRef',
    'videos',
    'eventRelations',
    'programItemRefs',
    'routeRef',
    'sourceRecords',
    'refundPolicy',
    'checkInPolicy',
  ].map((key): readonly [string, (body: Record<string, any>) => void, string] => [
    `capability ${key}`,
    (b) => {
      b[key] = 'x';
    },
    `event.unsupported_capability:${key}`,
  ]),
];

for (const [name, change, code] of unsupported)
  void test(`Event explicitly rejects unsupported variant: ${name}`, () => {
    const issues = check(withChange(change));
    assert.ok(issues.includes(code), `${code} not in ${JSON.stringify(issues)}`);
  });

void test('server-owned and derived fields cannot be authored', () => {
  for (const key of [
    'lifecycleStatus',
    'moderationStatus',
    'currentParticipants',
    'publisherRef',
    'startAtUtc',
    'endAtUtc',
  ]) {
    const issues = check(
      withChange((b) => {
        b[key] = 'x';
      }),
    );
    assert.ok(issues.includes(`event.server_owned_field:${key}`), key);
  }
});

void test('an unanswered taxonomy authority fails closed', () => {
  const unavailable = context({
    lookups: { ...lookups, subcategoryApplies: () => undefined, requiredCriteria: () => undefined },
  });
  const issues = check(validBody(), unavailable);
  assert.ok(issues.includes('event.taxonomy_unavailable'));
  assert.ok(issues.includes('event.criteria_registry_unavailable'));
});

void test('required criteria of the subcategory profile block submit', () => {
  const needing = context({ lookups: { ...lookups, requiredCriteria: () => ['level'] } });
  assert.ok(check(validBody(), needing).includes('event.criterion_required:level'));
  assert.deepEqual(
    check(
      withChange((b) => {
        b.criteria = { level: 'beginner' };
      }),
      needing,
    ),
    [],
  );
});

void test('a series longer than the projection window is capped', () => {
  const body = withChange((b) => {
    b.schedule = baseSchedule({
      scheduleMode: 'recurring',
      localStartDate: '2026-10-10',
      recurrence: {
        frequency: 'daily',
        interval: 1,
        endMode: 'never',
        exceptionLocalDates: [],
        dstGapPolicy: 'shiftForward',
        dstOverlapPolicy: 'earlierOffset',
      },
    });
    const day = 86400000;
    const start = Date.parse('2026-10-10T00:00:00.000Z');
    b.eventSlots = Array.from({ length: 181 }, (_, index) => {
      const iso = new Date(start + index * day).toISOString().slice(0, 10);
      return slot(index, iso, `${iso}T15:00:00.000Z`, `${iso}T17:00:00.000Z`);
    });
  });
  assert.ok(check(body).includes('event.occurrences_mismatch'));
});
