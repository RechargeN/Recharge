/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-member-access --
   Mutation table: each case edits a deeply nested clone of a valid JSON body, and
   the rules under test accept arbitrary untyped input by design. */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import {
  activityMediaIds,
  validateActivityBody,
} from '../../../src/modules/content/domain/type_rules/activity_rules.js';
import type {
  ContentValidationContext,
  ReferenceLookups,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

const userId = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
const placeId = '018FQ2Z8Q9N4M7K2T6V3W1X5YB';

const lookups: ReferenceLookups = {
  supportsLocale: () => true,
  subcategoryApplies: (typeId, categoryId, subcategoryId) =>
    typeId === 'activity' && categoryId === 'wellness_recharge' && subcategoryId === 'calm_walk',
  requiredCriteria: () => [],
  pointInServiceArea: () => true,
};

function context(overrides: Partial<ContentValidationContext> = {}): ContentValidationContext {
  return {
    typeId: 'activity',
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

function validBody(): Record<string, unknown> {
  return {
    title: 'Sunset walk by the river',
    categoryId: 'wellness_recharge',
    subcategoryId: 'calm_walk',
    shortDescription: 'A calm forty minute walk along the river bank',
    media: { coverImage: { mediaId: 'media-cover' }, gallery: [] },
    location: {
      latitude: 56.9496,
      longitude: 24.1052,
      pinConfirmed: true,
      accessNotes: 'Enter from the park gate and follow the river path.',
    },
    typicalDurationMinutes: { min: 30, max: 90 },
  };
}

function withChange(change: (body: Record<string, any>) => void): Record<string, unknown> {
  const body = structuredClone(validBody());
  change(body);
  return body;
}

const check = (body: Record<string, unknown>, ctx = context()) => validateActivityBody(body, ctx);

void test('Activity is available with its rule and media extractor', () => {
  const entry = resolveContentType('activity');
  assert.ok(entry);
  assert.equal(isContentTypeAvailable(entry), true);
  assert.equal(entry.validate, validateActivityBody);
  assert.equal(entry.mediaIds, activityMediaIds);
});

void test('a complete Activity body is valid, including every optional section', () => {
  assert.deepEqual(check(validBody()), []);
  const rich = withChange((b) => {
    b.fullDescription = 'Longer description of the route, the views and what to bring along.';
    b.media.gallery = [{ mediaId: 'g1', altText: 'River' }];
    b.location.addressLine = 'Riverside 1';
    b.location.linkedPlaceId = placeId;
    b.location.accessCaution = { isInformal: true, note: 'Path is not maintained in winter' };
    b.suggestedGroupSize = { min: 1, max: 6 };
    b.bestTime = { timeOfDay: 'evening', season: 'summer' };
    b.optionalContribution = {
      kind: 'donation',
      note: 'A coffee for the local volunteers',
      amountHint: { amountMinor: 300, currencyCode: 'EUR' },
    };
    b.criteria = { difficulty: 'easy' };
  });
  assert.deepEqual(check(rich), []);
  assert.deepEqual(activityMediaIds(rich), ['media-cover', 'g1']);
  assert.deepEqual(activityMediaIds({}), []);
});

void test('recommendations outside the suggested ranges are warnings, not failures', () => {
  const body = withChange((b) => {
    b.typicalDurationMinutes = { min: 10, max: 600 };
    b.suggestedGroupSize = { min: 1, max: 50 };
    b.location.accessCaution = { isInformal: true, note: 'Informal access across a field' };
  });
  assert.deepEqual(check(body), []);
});

void test('isInformal=false with an empty note normalizes to no caution', () => {
  const body = withChange((b) => {
    b.location.accessCaution = { isInformal: false };
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
      'activity.unknown_field:surprise',
    ],
    [
      'a start time turns it into an Event',
      (b) => {
        b.startDateTimeUtc = '2026-10-01T10:00:00Z';
      },
      'activity.forbidden_field:startDateTimeUtc',
    ],
    [
      'recurrence',
      (b) => {
        b.recurrence = { rule: 'weekly' };
      },
      'activity.forbidden_field:recurrence',
    ],
    [
      'capacity',
      (b) => {
        b.capacity = 10;
      },
      'activity.forbidden_field:capacity',
    ],
    [
      'pricing',
      (b) => {
        b.pricing = { mode: 'fixed' };
      },
      'activity.forbidden_field:pricing',
    ],
    [
      'booking url',
      (b) => {
        b.bookingUrl = 'https://example.com';
      },
      'activity.forbidden_field:bookingUrl',
    ],
    [
      'title too short',
      (b) => {
        b.title = 'Walk';
      },
      'activity.title_length',
    ],
    [
      'title too long',
      (b) => {
        b.title = 'x'.repeat(81);
      },
      'activity.title_length',
    ],
    [
      'short description too short',
      (b) => {
        b.shortDescription = 'Short';
      },
      'activity.short_description_length',
    ],
    [
      'full description too long',
      (b) => {
        b.fullDescription = 'x'.repeat(1001);
      },
      'activity.full_description_length',
    ],
    [
      'category missing',
      (b) => {
        delete b.categoryId;
      },
      'activity.category_required',
    ],
    [
      'subcategory missing',
      (b) => {
        delete b.subcategoryId;
      },
      'activity.subcategory_required',
    ],
    [
      'subcategory not Activity-applicable',
      (b) => {
        b.subcategoryId = 'football';
      },
      'activity.subcategory_not_applicable',
    ],
    [
      'criteria is not an object',
      (b) => {
        b.criteria = [];
      },
      'activity.criteria_invalid',
    ],
    [
      'cover missing',
      (b) => {
        delete b.media.coverImage;
      },
      'activity.cover_image_required',
    ],
    [
      'media missing',
      (b) => {
        delete b.media;
      },
      'activity.cover_image_required',
    ],
    [
      'gallery over the limit',
      (b) => {
        b.media.gallery = Array.from({ length: 13 }, (_, i) => ({ mediaId: `g${i}` }));
      },
      'activity.gallery_too_large',
    ],
    [
      'duplicate media',
      (b) => {
        b.media.gallery = [{ mediaId: 'media-cover' }];
      },
      'activity.media_duplicate',
    ],
    [
      'unreplaced local media id',
      (b) => {
        b.media.coverImage.mediaId = 'loc_c';
      },
      'activity.local_id_unreplaced',
    ],
    [
      'location missing',
      (b) => {
        delete b.location;
      },
      'activity.location_required',
    ],
    [
      'latitude missing',
      (b) => {
        delete b.location.latitude;
      },
      'activity.location_coordinates_required',
    ],
    [
      'latitude out of range',
      (b) => {
        b.location.latitude = 95;
      },
      'activity.location_coordinates_required',
    ],
    [
      'longitude not finite',
      (b) => {
        b.location.longitude = Number.POSITIVE_INFINITY;
      },
      'activity.location_coordinates_required',
    ],
    [
      'pin not confirmed',
      (b) => {
        b.location.pinConfirmed = false;
      },
      'activity.pin_confirmation_required',
    ],
    [
      'access notes missing',
      (b) => {
        delete b.location.accessNotes;
      },
      'activity.access_notes_required',
    ],
    [
      'access notes too short',
      (b) => {
        b.location.accessNotes = 'short';
      },
      'activity.access_notes_length',
    ],
    [
      'access notes too long',
      (b) => {
        b.location.accessNotes = 'x'.repeat(301);
      },
      'activity.access_notes_length',
    ],
    [
      'informal caution without a note',
      (b) => {
        b.location.accessCaution = { isInformal: true };
      },
      'activity.access_caution_note_required',
    ],
    [
      'informal caution note too long',
      (b) => {
        b.location.accessCaution = { isInformal: true, note: 'x'.repeat(201) };
      },
      'activity.access_caution_note_length',
    ],
    [
      'linked place is a local key',
      (b) => {
        b.location.linkedPlaceId = 'loc_place';
      },
      'activity.linked_place_invalid',
    ],
    [
      'contribution kind without a note',
      (b) => {
        b.optionalContribution = { kind: 'donation' };
      },
      'activity.contribution_note_required',
    ],
    [
      'contribution note too short',
      (b) => {
        b.optionalContribution = { kind: 'donation', note: 'tip' };
      },
      'activity.contribution_note_length',
    ],
    [
      'contribution note without a kind',
      (b) => {
        b.optionalContribution = { note: 'A coffee for volunteers' };
      },
      'activity.contribution_inconsistent',
    ],
    [
      'contribution amount without a kind',
      (b) => {
        b.optionalContribution = { amountHint: { amountMinor: 100, currencyCode: 'EUR' } };
      },
      'activity.contribution_inconsistent',
    ],
    [
      'contribution amount not positive',
      (b) => {
        b.optionalContribution = {
          kind: 'donation',
          note: 'A coffee for volunteers',
          amountHint: { amountMinor: 0, currencyCode: 'EUR' },
        };
      },
      'activity.contribution_amount_not_positive',
    ],
    [
      'contribution amount is floating point',
      (b) => {
        b.optionalContribution = {
          kind: 'donation',
          note: 'A coffee for volunteers',
          amountHint: { amountMinor: 1.5, currencyCode: 'EUR' },
        };
      },
      'activity.contribution_amount_not_positive',
    ],
    [
      'contribution currency not the market currency',
      (b) => {
        b.optionalContribution = {
          kind: 'donation',
          note: 'A coffee for volunteers',
          amountHint: { amountMinor: 100, currencyCode: 'USD' },
        };
      },
      'activity.contribution_currency_unsupported',
    ],
    [
      'unknown contribution kind',
      (b) => {
        b.optionalContribution = { kind: 'ticket', note: 'A coffee for volunteers' };
      },
      'activity.contribution_kind',
    ],
    [
      'duration missing',
      (b) => {
        delete b.typicalDurationMinutes;
      },
      'activity.duration_required',
    ],
    [
      'duration not positive',
      (b) => {
        b.typicalDurationMinutes = { min: 0, max: 60 };
      },
      'activity.duration_not_positive',
    ],
    [
      'duration min above max',
      (b) => {
        b.typicalDurationMinutes = { min: 90, max: 60 };
      },
      'activity.duration_range_invalid',
    ],
    [
      'group size not positive',
      (b) => {
        b.suggestedGroupSize = { min: 0, max: 4 };
      },
      'activity.group_size_not_positive',
    ],
    [
      'group size min above max',
      (b) => {
        b.suggestedGroupSize = { min: 5, max: 2 };
      },
      'activity.group_size_range_invalid',
    ],
    [
      'unknown time of day',
      (b) => {
        b.bestTime = { timeOfDay: 'noon' };
      },
      'activity.best_time_of_day',
    ],
    [
      'unknown season',
      (b) => {
        b.bestTime = { season: 'monsoon' };
      },
      'activity.best_season',
    ],
  ];

for (const [name, change, code] of invalidCases)
  void test(`Activity rejects: ${name}`, () => {
    const issues = check(withChange(change));
    assert.ok(issues.includes(code), `${code} not in ${JSON.stringify(issues)}`);
  });

void test('unanswered taxonomy authority fails closed', () => {
  const unavailable = context({
    lookups: { ...lookups, subcategoryApplies: () => undefined, requiredCriteria: () => undefined },
  });
  const issues = check(validBody(), unavailable);
  assert.ok(issues.includes('activity.taxonomy_unavailable'));
  assert.ok(issues.includes('activity.criteria_registry_unavailable'));
});

void test('required criteria of the subcategory profile block submit', () => {
  const needing = context({ lookups: { ...lookups, requiredCriteria: () => ['difficulty'] } });
  assert.ok(check(validBody(), needing).includes('activity.criterion_required:difficulty'));
  const provided = withChange((b) => {
    b.criteria = { difficulty: 'easy' };
  });
  assert.deepEqual(check(provided, needing), []);
});

void test('contribution currency follows the pinned market rather than a hard-coded currency', () => {
  const body = withChange((b) => {
    b.optionalContribution = {
      kind: 'donation',
      note: 'A coffee for the volunteers',
      amountHint: { amountMinor: 100, currencyCode: 'SEK' },
    };
  });
  assert.deepEqual(
    check(body, context({ market: { currencyCode: 'SEK', timezoneId: 'Europe/Riga' } })),
    [],
  );
  assert.ok(check(body).includes('activity.contribution_currency_unsupported'));
});

void test('required criteria treats whitespace as missing and preserves false and zero', () => {
  const needing = context({ lookups: { ...lookups, requiredCriteria: () => ['difficulty'] } });
  for (const value of [undefined, null, '', '   ']) {
    assert.ok(
      check(
        withChange((b) => {
          b.criteria = { difficulty: value };
        }),
        needing,
      ).includes('activity.criterion_required:difficulty'),
    );
  }
  for (const value of [false, 0]) {
    assert.deepEqual(
      check(
        withChange((b) => {
          b.criteria = { difficulty: value };
        }),
        needing,
      ),
      [],
    );
  }
});
