import assert from 'node:assert/strict';
import test from 'node:test';

import { validateActivityBody } from '../../../src/modules/content/domain/type_rules/activity_rules.js';
import { validateCollectionBody } from '../../../src/modules/content/domain/type_rules/collection_rules.js';
import { validateEventBody } from '../../../src/modules/content/domain/type_rules/event_rules.js';
import { validateRentalBody } from '../../../src/modules/content/domain/type_rules/rental_rules.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';

const locales = (supportsLocale: (locale: string) => boolean | undefined) =>
  ({
    lookups: {
      supportsLocale,
      subcategoryApplies: () => true,
      criteriaApply: () => true,
      isCategoryKnown: () => true,
    },
  }) as unknown as ContentValidationContext;
const known = locales((locale) => ['en', 'lv', 'ru'].includes(locale));
const unavailable = locales(() => undefined);

const types = [
  ['event', validateEventBody],
  ['activity', validateActivityBody],
  ['rental', validateRentalBody],
  ['collection', validateCollectionBody],
] as const;

const issues = (
  validate: (typeof types)[number][1],
  body: ContentBody,
  context: ContentValidationContext,
): readonly string[] => {
  try {
    return validate(body, context);
  } catch (error) {
    // A body this empty may stop a later rule; the language rule never throws.
    assert.fail(String(error));
  }
};

for (const [prefix, validate] of types) {
  void test(`${prefix}: contentLocale is optional, known and never an unknown field`, () => {
    const absent = issues(validate, {}, known);
    assert.ok(!absent.includes(`${prefix}.locale`));
    assert.ok(!absent.includes(`${prefix}.locale_unavailable`));

    const declared = issues(validate, { contentLocale: 'lv' }, known);
    assert.ok(!declared.includes(`${prefix}.locale`));
    assert.ok(!declared.includes(`${prefix}.unknown_field:contentLocale`));

    assert.ok(issues(validate, { contentLocale: 'de' }, known).includes(`${prefix}.locale`));
    assert.ok(issues(validate, { contentLocale: 42 }, known).includes(`${prefix}.locale`));
    assert.ok(
      issues(validate, { contentLocale: 'lv' }, unavailable).includes(
        `${prefix}.locale_unavailable`,
      ),
    );
  });
}
