import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  readLocalTaxonomy,
  taxonomyRevisionId,
} from '../../../src/modules/reference_data/infrastructure/local_taxonomy_reader.js';
import {
  projectFact,
  type ContentFact,
  type SourceRevision,
} from '../../../src/modules/catalog/domain/catalog_item.js';
import { parseDiscoverQuery } from '../../../src/modules/catalog/domain/discover_query.js';
import { evaluate } from '../../../src/modules/catalog/domain/evaluation.js';
import { standActivityBody } from '../../stand/stand_content_activity.js';
const refs = { taxonomyRevisionId };
const fact: ContentFact = {
  schemaVersion: 1,
  effectId: 'effect',
  kind: 'ContentPublished',
  contentId: 'content',
  publishedRevisionId: 'revision',
  pointerRevision: 1,
  visibility: 'visible',
  typeId: 'activity',
  publisherRef: { type: 'user', id: 'creator' },
  marketId: 'LV',
  referenceRevisions: refs,
  occurredAtUtc: '2026-10-11T00:00:00.000Z',
};
const revision: SourceRevision = {
  contentId: 'content',
  publishedRevisionId: 'revision',
  typeId: 'activity',
  marketId: 'LV',
  referenceRevisions: refs,
  publishedAtUtc: '2026-10-11T00:00:00.000Z',
  body: {
    ...standActivityBody({ coverMediaId: 'cover', galleryMediaIds: ['gallery-1', 'gallery-2'] }),
    privateAuthoringKey: 'secret',
    optionalContribution: {
      kind: 'donation',
      note: 'Optional local donation',
      amountHint: { amountMinor: 250, currencyCode: 'EUR' },
    },
  },
};
const read = readLocalTaxonomy(taxonomyRevisionId);
assert.ok(read.ok);
const project = (f: Partial<ContentFact> = {}, r: Partial<SourceRevision> = {}) =>
  projectFact({
    fact: { ...fact, ...f },
    revision: { ...revision, ...r },
    typeVisibilityPolicy: 'public_catalog',
    activityEnabled: true,
    taxonomy: read.dataset,
  });
void test('Activity projects public facts without pseudo Event fields or arbitrary criteria', () => {
  const result = project();
  assert.equal(result.state, 'listed');
  if (result.state !== 'listed' || result.item.typeId !== 'activity')
    throw new Error('not Activity');
  assert.deepEqual(result.item.typicalDurationMinutes, { min: 60, max: 120 });
  assert.deepEqual(result.item.bestTime, { timeOfDay: 'morning', season: 'any' });
  assert.equal(result.item.point.latitude, 56.9142);
  assert.equal(result.item.optionalContribution?.amountHint?.amountMinor, 250);
  for (const key of ['occurrences', 'timezoneId', 'price', 'criteria', 'privateAuthoringKey'])
    assert.equal(Object.hasOwn(result.item, key), false, key);
  const absent = project(
    {},
    { body: { ...revision.body, optionalContribution: undefined, bestTime: undefined } },
  );
  assert.equal(absent.state, 'listed');
  if (absent.state === 'listed')
    assert.equal(Object.hasOwn(absent.item, 'optionalContribution'), false);
  const empty = project({}, { body: { ...revision.body, optionalContribution: {} } });
  assert.equal(empty.state, 'listed');
  if (empty.state === 'listed')
    assert.equal(Object.hasOwn(empty.item, 'optionalContribution'), false);
});
void test('Activity cover/gallery suppression does not substitute another image', () => {
  const result = project({ suppressedMediaIds: ['cover', 'gallery-1'] });
  assert.equal(result.state, 'listed');
  if (result.state === 'listed' && result.item.typeId === 'activity') {
    assert.equal(result.item.coverMediaId, null);
    assert.deepEqual(result.item.galleryMediaIds, ['gallery-2']);
  }
});
void test('disabled, unavailable taxonomy and invalid standalone data fail closed', () => {
  assert.deepEqual(projectFact({ fact, revision, typeVisibilityPolicy: 'public_catalog' }), {
    state: 'excluded',
    reason: 'type_disabled',
  });
  assert.deepEqual(
    projectFact({ fact, revision, typeVisibilityPolicy: 'public_catalog', activityEnabled: true }),
    { state: 'excluded', reason: 'invalid_projection' },
  );
  for (const body of [
    { ...revision.body, typicalDurationMinutes: { min: 0, max: 5 } },
    { ...revision.body, criteria: {} },
    { ...revision.body, subcategoryId: 'sauna', categoryId: 'wellness_recharge' },
    { ...revision.body, location: { latitude: 56, longitude: 24, pinConfirmed: false } },
    { ...revision.body, bestTime: { season: 'nope' } },
  ])
    assert.equal(project({}, { body }).state, 'excluded');
  assert.deepEqual(project({ visibility: 'restricted' }), {
    state: 'excluded',
    reason: 'restricted',
  });
});
void test('Activity query evaluates evergreen geo/text, excludes Event-specific filters', () => {
  const result = project();
  assert.ok(result.state === 'listed');
  const q = parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV', typeIds: ['activity'] }, true);
  assert.ok(q.ok);
  assert.equal(evaluate(result.item, q.query, Date.parse('2099-01-01')).eligible, true);
  assert.equal(evaluate(result.item, { ...q.query, free: true }, Date.now()).eligible, false);
  assert.equal(
    evaluate(
      result.item,
      {
        ...q.query,
        timeWindow: { fromUtc: '2026-10-11T00:00:00Z', toUtc: '2026-10-12T00:00:00Z' },
      },
      Date.now(),
    ).eligible,
    false,
  );
  assert.equal(
    parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV', typeIds: ['activity'] }).ok,
    false,
  );
});
