import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ratingProjection, type ReviewRecord } from '../../src/modules/reviews/review_policy.js';
import {
  appealDeadline,
  notificationSuppressed,
} from '../../src/modules/trust_safety/safety_policy.js';
const row = (rating: number, extra: Partial<ReviewRecord> = {}): ReviewRecord => ({
  schemaVersion: 1,
  reviewId: 'r',
  authorId: 'u',
  contentId: 'c',
  typeId: 'place',
  marketId: 'LV',
  revision: 1,
  rating,
  text: '',
  edited: false,
  deleted: false,
  moderationHold: null,
  policyRevision: 'p',
  evidence: null,
  createdAtUtc: '',
  updatedAtUtc: '',
  verified: false,
  ...extra,
});
void test('rating uses integer arithmetic, visibility and a three-review threshold', () => {
  assert.equal(ratingProjection([row(1), row(5)]).averageScaled, null);
  assert.deepEqual(
    ratingProjection([
      row(1),
      row(5),
      row(4),
      row(2, { deleted: true }),
      row(3, { moderationHold: 'd' }),
    ]),
    {
      count: 3,
      sum: 10,
      distribution: [1, 0, 0, 1, 1],
      averageScaled: 3333,
      scaleFactor: 1000,
      policyRevision: 'local-owner-2026-10-15-v1',
    },
  );
});
void test('rating rebuild is independent of source ordering', () => {
  const rows = [row(1), row(2), row(5), row(5)];
  assert.deepEqual(ratingProjection(rows), ratingProjection(rows.reverse()));
});
void test('appeal window uses six calendar months, including month end', () => {
  assert.equal(appealDeadline('2026-08-31T12:00:00.000Z'), '2027-02-28T12:00:00.000Z');
  assert.equal(appealDeadline('2026-01-31T12:00:00.000Z'), '2026-07-31T12:00:00.000Z');
});
void test('service and safety notices survive both relations', () => {
  for (const kind of [
    'bookingCancelled',
    'bookingChanged',
    'venueChanged',
    'safety',
    'reconfirmation',
  ])
    assert.equal(notificationSuppressed(kind, true, true), false);
  assert.equal(notificationSuppressed('newPublication', true, false), true);
});
