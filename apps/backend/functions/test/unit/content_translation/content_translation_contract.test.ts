import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import {
  allowlistedFields,
  cacheKeyOf,
  contentTranslationAllowlist,
  contentTranslationModes,
  declaredSourceLocale,
  parseContentTranslationRequest,
} from '../../../src/modules/content_translation/content_translation_contract.js';
import { MockTranslationProvider } from '../../../src/modules/content_translation/content_translation_provider.js';
import {
  acceptProviderOutput,
  redactContacts,
} from '../../../src/modules/content_translation/content_translation_text.js';

const request = () => ({
  schemaVersion: 1,
  requestId: 'req-1',
  contentId: randomUUID(),
  publishedRevisionId: randomUUID(),
  targetLocale: 'ru',
});

void test('a request with any text or unknown field is refused', () => {
  assert.ok(parseContentTranslationRequest(request()));
  for (const extra of [
    { text: 'translate me' },
    { fields: { title: 'x' } },
    { sourceLocale: 'lv' },
  ])
    assert.equal(parseContentTranslationRequest({ ...request(), ...extra }), null);
  assert.equal(parseContentTranslationRequest({ ...request(), contentId: '../x' }), null);
  assert.equal(parseContentTranslationRequest({ ...request(), schemaVersion: 2 }), null);
});

void test('allowlist: Find People and terms never leave Content; a new field needs a decision', () => {
  const body = {
    title: 'Title',
    shortDescription: 'Short',
    fullDescription: 'Full',
    cancellationPolicy: 'terms',
    safetyNotice: 'safety',
    ageRestriction: '18+',
    accessCaution: 'caution',
    rentalTerms: 'terms',
    venueName: 'venue',
    organizerName: 'organizer',
    address: 'address',
    contact: 'contact',
    privateNotes: 'private',
  };
  assert.equal(allowlistedFields('find_people', body), null);
  assert.equal(allowlistedFields('unknown_type', body), null);
  assert.equal(allowlistedFields('constructor', body), null);
  for (const typeId of Object.keys(contentTranslationAllowlist))
    assert.deepEqual(allowlistedFields(typeId, body), {
      title: 'Title',
      shortDescription: 'Short',
      fullDescription: 'Full',
    });
  // Positive control: the same check does see a field once it is allowlisted.
  const extended = { event: ['title', 'safetyNotice'] } as unknown as Parameters<
    typeof allowlistedFields
  >[2];
  assert.deepEqual(allowlistedFields('event', body, extended), {
    title: 'Title',
    safetyNotice: 'safety',
  });
});

void test('the source language is read as declared and never guessed', () => {
  assert.equal(declaredSourceLocale({ contentLocale: 'lv-LV' }), 'lv');
  assert.equal(declaredSourceLocale({ contentLocale: 'RU' }), 'ru');
  assert.equal(declaredSourceLocale({ title: 'no locale' }), null);
  assert.equal(declaredSourceLocale({ contentLocale: '12' }), null);
});

void test('every cache key part changes the key', () => {
  const base = {
    contentId: 'c',
    publishedRevisionId: 'r',
    sourceHash: 'h',
    sourceLocale: 'lv',
    targetLocale: 'ru',
    providerRef: 'p',
    engineRevision: 'e',
  };
  for (const key of Object.keys(base))
    assert.notEqual(cacheKeyOf(base), cacheKeyOf({ ...base, [key]: 'other' }), key);
});

void test('contacts become tokens for the provider and return in the answer', () => {
  const redacted = redactContacts({
    title: 'Open day',
    fullDescription: 'Write to host@example.com or call +371 2000 0000. Room 12, 2 hours.',
  });
  assert.equal(redacted.fields.title, 'Open day');
  assert.doesNotMatch(redacted.fields.fullDescription!, /example\.com|2000 0000/u);
  assert.match(redacted.fields.fullDescription!, /Room 12, 2 hours/u);
  const restored = acceptProviderOutput(redacted, {
    title: 'День открытых дверей',
    fullDescription: 'Пишите ' + redacted.fields.fullDescription!.slice(9),
  });
  assert.match(restored!.fullDescription!, /host@example\.com/u);
  assert.match(restored!.fullDescription!, /\+371 2000 0000/u);
});

void test('provider output is untrusted: shape, tokens, markup and length are checked', () => {
  const redacted = redactContacts({ title: 'Mail a@example.com now' });
  const token = redacted.fields.title!.match(/⟦\d+⟧/u)![0];
  const good = 'Пишите ' + token;
  assert.ok(acceptProviderOutput(redacted, { title: good }));
  for (const bad of [
    null,
    'text',
    [],
    {},
    { title: 42 },
    { title: '   ' },
    { title: 'токен потерян' },
    { title: good + ' ' + token },
    { title: good, extra: 'x' },
    { title: good + ' <b>bold</b>' },
    { title: good + ' [x](https://example.com)' },
    { title: good + '\u0007' },
    { title: good + 'x'.repeat(5000) },
  ])
    assert.equal(acceptProviderOutput(redacted, bad), null, JSON.stringify(bad));
});

void test('the mock adapter makes no network call and keeps tokens', async () => {
  const provider = new MockTranslationProvider();
  const redacted = redactContacts({ title: 'Mail a@example.com now' });
  const output = await provider.translate({
    sourceLocale: 'lv',
    targetLocale: 'ru',
    fields: redacted.fields,
  });
  assert.equal(acceptProviderOutput(redacted, output)?.title, '[lv→ru] Mail a@example.com now');
});

void test('amendment 1: every allowlisted type has exactly one mode; Find People has none', () => {
  assert.deepEqual(
    Object.keys(contentTranslationModes).sort(),
    Object.keys(contentTranslationAllowlist).sort(),
  );
  assert.equal(contentTranslationModes.find_people, undefined);
  assert.deepEqual(
    Object.keys(contentTranslationModes)
      .filter((typeId) => contentTranslationModes[typeId] === 'publication')
      .sort(),
    ['activity', 'collection', 'place', 'rental', 'route'],
  );
});
