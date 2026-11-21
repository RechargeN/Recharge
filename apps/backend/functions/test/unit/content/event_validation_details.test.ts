import assert from 'node:assert/strict';
import test from 'node:test';

import { publicValidationDetails } from '../../../src/modules/content/domain/validation_details.js';

/**
 * Round 1 (2026-11-20): on A34 the app showed only "check the fields" because
 * every Event code was dropped. Each Event refusal now names its field; codes
 * stay public snake_case and paths stay inside /body.
 */
void test('Event refusals carry their field path', () => {
  assert.deepEqual(
    publicValidationDetails([
      'event.full_description_length',
      'event.short_description_length',
      'event.title_length',
      'event.local_id_unreplaced',
      'event.location_pin_unconfirmed',
      'event.fixed_price_required',
      'event.capacity_required',
    ]),
    [
      { code: 'event.full_description_length', fieldPath: '/body/fullDescription' },
      { code: 'event.short_description_length', fieldPath: '/body/shortDescription' },
      { code: 'event.title_length', fieldPath: '/body/title' },
      { code: 'event.local_id_unreplaced', fieldPath: '/body/media' },
      { code: 'event.location_pin_unconfirmed', fieldPath: '/body/location' },
      { code: 'event.fixed_price_required', fieldPath: '/body/pricing' },
      { code: 'event.capacity_required', fieldPath: '/body/participants' },
    ],
  );
});

void test('unknown Event codes stay private', () => {
  assert.deepEqual(publicValidationDetails(['event.not_a_real_code']), []);
});
