import assert from 'node:assert/strict';
import test from 'node:test';
import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import {
  validateSessionBody,
  sessionMediaIds,
} from '../../../src/modules/content/domain/type_rules/session_rules.js';
import { EmulatorSyntheticReferenceData } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';

interface Fixture {
  serverOwnerUserId: string;
  cases: { name: string; body: ContentBody; expectedIssues: string[] }[];
}
async function setup() {
  const fixture = (await readContentJson('fixtures/session_create_compat.json')) as Fixture;
  const ref = await new EmulatorSyntheticReferenceData().resolve({
    marketId: 'LV',
    typeId: 'session',
  });
  assert.ok(ref.ok);
  const context: ContentValidationContext = {
    typeId: 'session',
    marketId: 'LV',
    publisherRef: { type: 'user', id: fixture.serverOwnerUserId as never },
    createdByUserId: fixture.serverOwnerUserId,
    actorUserId: fixture.serverOwnerUserId,
    nowUtc: '2026-10-18T10:00:00Z',
    draftRevision: 1,
    market: ref.market,
    lookups: ref.lookups,
  };
  return { fixture, context };
}
void test('D3.5 missing dependency, scope, timezone, strict numbers and closing exceptions fail closed', async () => {
  const { fixture, context } = await setup();
  const body = fixture.cases[0]!.body;
  assert.deepEqual(validateSessionBody(body, context), []);
  assert.equal(sessionMediaIds(body).length, 1);
  assert.ok(
    validateSessionBody(body, {
      ...context,
      lookups: { ...context.lookups, sessionProjectionWindowDays: () => undefined },
    }).includes('session.policy_unavailable'),
  );
  assert.ok(
    validateSessionBody(body, {
      ...context,
      publisherRef: { type: 'page', id: context.publisherRef.id },
    }).includes('session_publisher_ineligible'),
  );
  for (const day of [0, 8, 1.5, '1']) {
    const b = structuredClone(body);
    const d = b.session as Record<string, unknown>;
    const s = d.schedule as Record<string, unknown>;
    s.weekly_rules = [
      {
        id: '22222222-2222-4222-8222-222222222222',
        iso_weekday: day,
        start_minute_local: 0,
        end_minute_local_exclusive: 1440,
      },
    ];
    assert.ok(validateSessionBody(b, context).includes('session_weekday_invalid'));
  }
  for (const date of ['2027-02-29', '2026-13-01', '2026-10-18']) {
    const b = structuredClone(body);
    const d = b.session as Record<string, unknown>;
    d.exceptions = [
      {
        id: '44444444-4444-4444-8444-444444444444',
        start_date_local: date,
        end_date_local: date,
        all_day: true,
        created_by_user_id: context.createdByUserId,
        created_at_utc: context.nowUtc,
      },
    ];
    const issues = validateSessionBody(b, context);
    assert.equal(issues.includes('session_exception_invalid'), date !== '2026-10-18');
  }
  // DST days are valid rule dates: the server does not expand or shift them.
  for (const date of ['2026-03-29', '2026-10-25', '2028-02-29']) {
    const b = structuredClone(body);
    (b.session as Record<string, unknown>).exceptions = [
      {
        id: '44444444-4444-4444-8444-444444444444',
        start_date_local: date,
        end_date_local: date,
        all_day: true,
        created_by_user_id: context.createdByUserId,
        created_at_utc: context.nowUtc,
      },
    ];
    assert.deepEqual(validateSessionBody(b, context), []);
  }
});

void test('closing exception cap counts active/future dates, not retained past history', async () => {
  const { fixture, context } = await setup();
  for (const date of ['2020-01-01', '2027-01-01']) {
    const body = structuredClone(fixture.cases[0]!.body);
    (body.session as Record<string, unknown>).exceptions = Array.from({ length: 367 }, (_, i) => ({
      id: `44444444-4444-4444-8444-${i.toString().padStart(12, '0')}`,
      start_date_local: date,
      end_date_local: date,
      all_day: true,
      created_by_user_id: context.createdByUserId,
      created_at_utc: context.nowUtc,
    }));
    assert.equal(
      validateSessionBody(body, context).includes('session_exception_invalid'),
      date !== '2020-01-01',
    );
  }
});

void test('accepted schedule/party boundary values are inclusive and beyond-bound values refuse', async () => {
  const { fixture, context } = await setup();
  for (const [field, valid, invalid, code] of [
    ['slot_duration_minutes', [30, 180], [29, 181], 'session_duration_out_of_range'],
    ['buffer_after_slot_minutes', [0, 180], [-1, 181], 'session_buffer_out_of_range'],
    ['min_notice_minutes', [0, 10080], [-1, 10081], 'session_notice_out_of_range'],
  ] as const) {
    for (const value of [...valid, ...invalid]) {
      const b = structuredClone(fixture.cases[0]!.body);
      const data = b.session as Record<string, unknown>;
      (data.schedule as Record<string, unknown>)[field] = value;
      assert.equal(
        validateSessionBody(b, context).includes(code),
        (invalid as readonly number[]).includes(value),
        `${field}:${value}`,
      );
    }
  }
  for (const count of [1, 20, 0, 21]) {
    const b = structuredClone(fixture.cases[0]!.body);
    (b.session as Record<string, unknown>).max_party_size = count;
    assert.equal(
      validateSessionBody(b, context).includes('session_party_size_out_of_range'),
      count === 0 || count === 21,
    );
  }
});

void test('Session required copy bounds and explicit localized media confirmation fail closed', async () => {
  const { fixture, context } = await setup();
  for (const [field, min, max] of [
    ['title', 5, 80],
    ['shortDescription', 20, 180],
    ['fullDescription', 50, 2000],
  ] as const) {
    for (const length of [min - 1, min, max, max + 1]) {
      const body = structuredClone(fixture.cases[0]!.body);
      (body as Record<string, unknown>)[field] = 'x'.repeat(length);
      assert.equal(
        validateSessionBody(body, context).includes(`session.${field}`),
        length < min || length > max,
        `${field}:${length}`,
      );
    }
  }
  for (const change of [
    (m: Record<string, unknown>) => {
      delete m.rightsConfirmed;
    },
    (m: Record<string, unknown>) => {
      m.rightsConfirmed = 'true';
    },
    (m: Record<string, unknown>) => {
      (m.coverImage as Record<string, unknown>).altText = { ru: 'Court' };
    },
    (m: Record<string, unknown>) => {
      (m.coverImage as Record<string, unknown>).altText = { en: ' ' };
    },
  ]) {
    const body = structuredClone(fixture.cases[0]!.body);
    change(body.media as Record<string, unknown>);
    assert.ok(validateSessionBody(body, context).includes('session_media_incomplete'));
  }
});

void test('Session required resource text does not inherit unaccepted Event or Place length caps', async () => {
  const { fixture, context } = await setup();
  const body = structuredClone(fixture.cases[0]!.body);
  const data = body.session as Record<string, unknown>;
  const location = body.location as Record<string, unknown>;
  data.resource_name = 'Resource '.repeat(50);
  location.city = 'City '.repeat(30);
  location.venueName = 'Venue '.repeat(40);
  location.addressLine1 = 'Address '.repeat(50);
  assert.deepEqual(validateSessionBody(body, context), []);
});

void test('Session local minute, adjacency, overlap and weekly range count contract boundaries', async () => {
  const { fixture, context } = await setup();
  const rulesBody = (ranges: readonly (readonly [number, number, number])[]) => {
    const body = structuredClone(fixture.cases[0]!.body);
    ((body.session as Record<string, unknown>).schedule as Record<string, unknown>).weekly_rules =
      ranges.map(([day, start, end], i) => ({
        id: `22222222-2222-4222-8222-${i.toString().padStart(12, '0')}`,
        iso_weekday: day,
        start_minute_local: start,
        end_minute_local_exclusive: end,
      }));
    return body;
  };
  assert.deepEqual(validateSessionBody(rulesBody([[1, 0, 1440]]), context), []);
  assert.deepEqual(
    validateSessionBody(
      rulesBody([
        [1, 0, 60],
        [1, 60, 120],
      ]),
      context,
    ),
    [],
  );
  for (const [start, end] of [
    [-1, 60],
    [0, 1441],
    [60, 60],
    [1380, 60],
    [0.5, 60],
    [0, 60.5],
  ])
    assert.ok(
      validateSessionBody(rulesBody([[1, start!, end!]]), context).includes(
        'session_range_invalid',
      ),
    );
  for (const second of [
    [59, 120],
    [0, 60],
  ] as const)
    assert.ok(
      validateSessionBody(
        rulesBody([
          [1, 0, 60],
          [1, ...second],
        ]),
        context,
      ).includes('session_range_overlap'),
    );
  const four = [0, 120, 240, 360].map((start) => [1, start, start + 60] as const);
  assert.deepEqual(validateSessionBody(rulesBody(four), context), []);
  assert.ok(
    validateSessionBody(rulesBody([...four, [1, 480, 540]]), context).includes(
      'session.too_many_ranges',
    ),
  );
  const twentyEight = Array.from({ length: 7 }, (_, day) =>
    [0, 120, 240, 360].map((start) => [day + 1, start, start + 60] as const),
  ).flat();
  assert.deepEqual(validateSessionBody(rulesBody(twentyEight), context), []);
  assert.notDeepEqual(validateSessionBody(rulesBody([...twentyEight, [7, 480, 540]]), context), []);
  assert.ok(validateSessionBody(rulesBody([]), context).includes('session_schedule_empty'));
});
void test('Session personal scope, explicit timezone confirmation and DST version cannot be claimed by default', async () => {
  const { fixture, context } = await setup();
  assert.ok(
    validateSessionBody(fixture.cases[0]!.body, {
      ...context,
      publisherRef: { type: 'user', id: '99999999-9999-4999-8999-999999999999' as never },
    }).includes('session_publisher_ineligible'),
  );
  const body = structuredClone(fixture.cases[0]!.body);
  const data = body.session as Record<string, unknown>;
  data.timezone_confirmed = false;
  assert.ok(validateSessionBody(body, context).includes('session_timezone_invalid'));
  data.timezone_confirmed = true;
  (data.schedule as Record<string, unknown>).dst_policy_version = 2;
  assert.ok(validateSessionBody(body, context).includes('session.dst_policy'));
});
