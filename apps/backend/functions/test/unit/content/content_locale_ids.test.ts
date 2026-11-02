import assert from 'node:assert/strict';
import { test } from 'node:test';

import { contentLocaleIds } from '../../../src/modules/content/infrastructure/emulator_reference_data.js';

void test('content accepts the canonical locales and the older lv', () => {
  for (const locale of ['lv-LV', 'en', 'ru', 'lv']) {
    assert.ok(contentLocaleIds.includes(locale), locale);
  }
  // Positive control: a market-suffixed form is not an R1 identifier.
  assert.equal(contentLocaleIds.includes('en-LV'), false);
});
