import assert from 'node:assert/strict';
import test from 'node:test';

import {
  IssueCollector,
  containsContactLike,
  hasUnreplacedLocalId,
  intervalsOverlap,
  isAllCaps,
  isEmail,
  isIanaZone,
  isInt,
  isLocalDate,
  isMinorUnits,
  isPhone,
  isSafeHttpsUrl,
  isText,
  normalizedLength,
  normalizeText,
  weeklyIntervals,
} from '../../../src/modules/content/domain/type_rules/validation_context.js';

void test('text is measured in code points after trim and whitespace collapsing', () => {
  assert.equal(normalizeText('  a   b \n c '), 'a b c');
  assert.equal(normalizedLength('  ab  '), 2);
  assert.equal(normalizedLength('😀😀'), 2);
  assert.equal(isText('ab', 2, 5), true);
  assert.equal(isText(' a ', 2, 5), false);
  assert.equal(isText('abcdef', 2, 5), false);
  assert.equal(isText(5, 1, 5), false);
});

void test('numbers and dates are strict', () => {
  assert.equal(isInt(5, 1, 10), true);
  assert.equal(isInt(5.5, 1, 10), false);
  assert.equal(isInt('5', 1, 10), false);
  assert.equal(isMinorUnits(700), true);
  assert.equal(isMinorUnits(7.5), false);
  assert.equal(isMinorUnits(-1), false);
  assert.equal(isMinorUnits(Number.MAX_SAFE_INTEGER + 2), false);
  assert.equal(isLocalDate('2026-02-28'), true);
  assert.equal(isLocalDate('2026-02-30'), false);
  assert.equal(isLocalDate('2026-2-3'), false);
  assert.equal(isIanaZone('Europe/Riga'), true);
  assert.equal(isIanaZone('UTC'), true);
  assert.equal(isIanaZone('Riga'), false);
  assert.equal(isIanaZone('Mars/Base'), false);
});

void test('public links are HTTPS only without credentials or app schemes', () => {
  assert.equal(isSafeHttpsUrl('https://example.com/menu'), true);
  for (const bad of [
    'http://example.com/menu',
    'javascript:alert(1)',
    'data:text/html,hi',
    'https://user:pw@example.com/',
    'https://localhost/',
    'https://example.com/a b',
    'myapp://open',
    '',
    42,
  ])
    assert.equal(isSafeHttpsUrl(bad), false, String(bad));
});

void test('contacts and free-text guards', () => {
  assert.equal(isEmail('hello@example.com'), true);
  assert.equal(isEmail('hello@'), false);
  assert.equal(isPhone('+371 2000 0000'), true);
  assert.equal(isPhone('12'), false);
  assert.equal(isPhone('call me'), false);
  assert.equal(containsContactLike('Call +371 2000 0000 now'), true);
  assert.equal(containsContactLike('mail me a@b.co'), true);
  assert.equal(containsContactLike('see https://x.co'), true);
  assert.equal(containsContactLike('Old town greenhouse'), false);
  assert.equal(isAllCaps('GREAT PLACE'), true);
  assert.equal(isAllCaps('Great Place'), false);
  assert.equal(isAllCaps('ABC'), false);
});

void test('weekly intervals carry an overnight tail and detect overlap', () => {
  const overnight = weeklyIntervals([
    { dayOfWeek: 1, openMinute: 22 * 60, closeMinute: 2 * 60, closesNextDay: true },
  ]);
  assert.deepEqual(overnight, [{ start: 22 * 60, end: 24 * 60 + 2 * 60 }]);
  // Sunday night wraps into Monday of the same weekly cycle.
  const wrapping = weeklyIntervals([
    { dayOfWeek: 7, openMinute: 23 * 60, closeMinute: 60, closesNextDay: true },
  ]);
  assert.equal(wrapping.length, 2);
  assert.equal(intervalsOverlap(wrapping), false);
  assert.equal(
    intervalsOverlap([
      ...wrapping,
      ...weeklyIntervals([
        { dayOfWeek: 1, openMinute: 30, closeMinute: 120, closesNextDay: false },
      ]),
    ]),
    true,
  );
  assert.equal(
    intervalsOverlap(
      weeklyIntervals([
        { dayOfWeek: 1, openMinute: 540, closeMinute: 780, closesNextDay: false },
        { dayOfWeek: 1, openMinute: 780, closeMinute: 1080, closesNextDay: false },
      ]),
    ),
    false,
  );
});

void test('unreplaced local ids are found in identifier-valued fields only', () => {
  assert.equal(hasUnreplacedLocalId({ media: { coverImage: { mediaId: 'loc_1' } } }), true);
  assert.equal(hasUnreplacedLocalId({ hours: { weeklyPeriods: [{ id: 'loc_p1' }] } }), true);
  assert.equal(hasUnreplacedLocalId({ itemIds: ['ok', 'loc_2'] }), true);
  assert.equal(hasUnreplacedLocalId({ mediaRefs: ['ok', 'loc_3'] }), true);
  assert.equal(hasUnreplacedLocalId({ mediaRefs: ['ok'] }), false);
  assert.equal(hasUnreplacedLocalId({ title: 'loc_ is only a title' }), false);
  assert.equal(hasUnreplacedLocalId({ media: { coverImage: { mediaId: 'media-1' } } }), false);
});

void test('issue collector is unique and bounded', () => {
  const issues = new IssueCollector();
  issues.add('a');
  issues.add('a');
  assert.equal(issues.require(false, 'b'), false);
  assert.equal(issues.require(true, 'c'), true);
  for (let index = 0; index < 200; index += 1) issues.add(`x${index}`);
  const result = issues.result();
  assert.equal(result.length, 50);
  assert.equal(new Set(result).size, 50);
  assert.equal(Object.isFrozen(result), true);
});
