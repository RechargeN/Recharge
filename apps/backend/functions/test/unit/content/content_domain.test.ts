import assert from 'node:assert/strict';
import test from 'node:test';

import { contentTypeIds } from '../../../src/contracts/content_v1.js';
import {
  assertBoundedBody,
  createContentDraft,
  updateContentDraftBody,
  withDraftStatus,
} from '../../../src/modules/content/domain/content_draft.js';
import {
  contentTypeRegistry,
  hasSourceContract,
  mediaIdsOf,
  resolveContentType,
  validatePlaceBody,
} from '../../../src/modules/content/domain/content_type_registry.js';
import { ContentDomainRefusal } from '../../../src/modules/content/domain/failures.js';
import { activateRevision } from '../../../src/modules/content/domain/publication_pointer.js';
import {
  assertPublishable,
  createPublicationSubmission,
  withSubmissionState,
} from '../../../src/modules/content/domain/publication_submission.js';
import {
  canonicalJson,
  createPublishedRevision,
  sha256Hex,
} from '../../../src/modules/content/domain/published_revision.js';
import { parseEntityId } from '../../../src/shared/ids.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';

const id = (suffix: string) => parseEntityId(`018FQ2Z8Q9N4M7K2T6V3W1X5${suffix}`);
const now = parseUtcInstant('2026-09-29T10:00:00.000Z');
const later = parseUtcInstant('2026-09-29T10:05:00.000Z');
const references = {
  marketConfigRevisionId: 'mc-lv-1',
  taxonomyRevisionId: 'tx-1',
  localizationRevisionId: 'loc-1',
};
const placeBody = {
  title: 'Vermanes garden greenhouse',
  categoryId: 'art_culture_museums',
  subcategoryId: 'museum',
  geoVisibility: 'exact',
  location: { latitude: 56.9496, longitude: 24.1052 },
};

function draft() {
  return createContentDraft({
    draftId: id('YA'),
    contentId: id('YB'),
    typeId: 'place',
    publisherRef: { type: 'user', id: id('YC') },
    marketId: 'LV',
    body: placeBody,
    referenceRevisions: references,
    createdByUserId: id('YC'),
    nowUtc: now,
  });
}

function refusalCode(action: () => unknown): string | undefined {
  try {
    action();
  } catch (error) {
    return error instanceof ContentDomainRefusal ? error.code : 'other';
  }
  return undefined;
}

void test('registry has exactly the ten accepted types and never Quick Plan', () => {
  assert.deepEqual(
    contentTypeRegistry.map((item) => item.typeId),
    [...contentTypeIds],
  );
  assert.equal(contentTypeRegistry.length, 10);
  assert.equal(resolveContentType('quick_plan'), null);
  assert.equal(resolveContentType('place_v2'), null);
  assert.equal(resolveContentType(undefined), null);
  assert.equal(Object.isFrozen(contentTypeRegistry), true);
});

void test('only Place has a source contract; the other nine fail closed', () => {
  const withContract = contentTypeRegistry.filter(hasSourceContract).map((item) => item.typeId);
  assert.deepEqual(withContract, ['place']);
  for (const item of contentTypeRegistry.filter((entry) => entry.typeId !== 'place'))
    assert.equal(item.validate, undefined, item.typeId);
});

void test('Place validator accepts a complete body and reports bounded issues', () => {
  assert.deepEqual(validatePlaceBody(placeBody), []);
  const issues = validatePlaceBody({
    title: '   ',
    categoryId: 'x',
    subcategoryId: '',
    geoVisibility: 'secret',
    location: { latitude: 91, longitude: 24 },
    openingHours: [{ weekday: 9, opens: '25:00', closes: '10:00' }],
    mediaIds: [1],
    surprise: true,
  });
  assert.deepEqual(
    new Set(issues),
    new Set([
      'unknown_field:surprise',
      'title',
      'subcategoryId',
      'geoVisibility',
      'location',
      'openingHours',
      'mediaIds',
    ]),
  );
  assert.deepEqual(mediaIdsOf({ mediaIds: ['m1', 'm2'] }), ['m1', 'm2']);
  assert.deepEqual(mediaIdsOf({ mediaIds: [1] }), []);
});

void test('draft creation is deep-frozen, versioned and binds an immutable publisher origin', () => {
  const created = draft();
  assert.equal(created.revision, 1);
  assert.equal(created.status, 'editing');
  assert.deepEqual(created.publisherBindingOrigin, created.publisherRef);
  assert.equal(Object.isFrozen(created.body), true);
  assert.throws(() => {
    (created.body as Record<string, unknown>).title = 'changed';
  });
});

void test('update requires the expected revision and cannot edit a submitted draft', () => {
  const created = draft();
  const updated = updateContentDraftBody(
    created,
    1,
    { ...placeBody, title: 'New' },
    references,
    later,
  );
  assert.equal(updated.revision, 2);
  assert.equal(created.revision, 1);
  assert.equal(
    refusalCode(() => updateContentDraftBody(created, 5, placeBody, references, later)),
    'revision_conflict',
  );
  const submitted = withDraftStatus(updated, 'submitted', later);
  assert.equal(submitted.revision, 2);
  assert.equal(
    refusalCode(() => updateContentDraftBody(submitted, 2, placeBody, references, later)),
    'revision_conflict',
  );
});

void test('body bounds reject arrays, oversized and over-deep input', () => {
  assert.equal(
    refusalCode(() => assertBoundedBody([])),
    'validation_failed',
  );
  assert.equal(
    refusalCode(() => assertBoundedBody(null)),
    'validation_failed',
  );
  assert.equal(
    refusalCode(() => assertBoundedBody({ text: 'x'.repeat(70 * 1024) })),
    'validation_failed',
  );
  let nested: Record<string, unknown> = {};
  for (let level = 0; level < 12; level += 1) nested = { child: nested };
  assert.equal(
    refusalCode(() => assertBoundedBody(nested)),
    'validation_failed',
  );
  assert.equal(
    refusalCode(() => assertBoundedBody({ a: { b: 1 } })),
    undefined,
  );
});

void test('a type without pre-publication moderation needs a recorded policy decision', () => {
  const created = draft();
  const base = {
    submissionId: id('YD'),
    draft: created,
    eligibilityAuthorityRevision: 1,
    referenceRevisions: references,
    nowUtc: now,
  };
  assert.equal(
    refusalCode(() =>
      createPublicationSubmission({
        ...base,
        moderation: {
          profileId: 'place.default',
          requiresPrePublicationModeration: false,
          policyRevision: 'p1',
        },
      }),
    ),
    'policy_unavailable',
  );
  const approved = createPublicationSubmission({
    ...base,
    moderation: {
      profileId: 'place.default',
      requiresPrePublicationModeration: false,
      policyRevision: 'p1',
      policyDecisionId: 'pd-1',
    },
  });
  assert.equal(approved.state, 'approved_for_publication');
  const reviewed = createPublicationSubmission({
    ...base,
    moderation: {
      profileId: 'place.default',
      requiresPrePublicationModeration: true,
      policyRevision: 'p1',
    },
  });
  assert.equal(reviewed.state, 'under_review');
  assert.equal(
    refusalCode(() => assertPublishable(reviewed)),
    'moderation_required',
  );
  assert.equal(
    refusalCode(() => assertPublishable(approved)),
    undefined,
  );
  const published = withSubmissionState(approved, 'published', later);
  assert.equal(
    refusalCode(() => assertPublishable(published)),
    'revision_conflict',
  );
  assert.equal(published.revision, 2);
});

void test('published revision is immutable, hash-stable and copies authorship from the draft', () => {
  const created = draft();
  const submission = createPublicationSubmission({
    submissionId: id('YD'),
    draft: created,
    moderation: {
      profileId: 'place.default',
      requiresPrePublicationModeration: false,
      policyRevision: 'p1',
      policyDecisionId: 'pd-1',
    },
    eligibilityAuthorityRevision: 1,
    referenceRevisions: references,
    nowUtc: now,
  });
  const revision = createPublishedRevision({
    publishedRevisionId: id('YE'),
    revisionNumber: 1,
    draft: created,
    submission,
    referenceRevisions: references,
    mediaRevision: 'media-1',
    nowUtc: later,
  });
  assert.deepEqual(revision.publisherRef, created.publisherBindingOrigin);
  assert.equal(revision.bodyHash, sha256Hex(canonicalJson(placeBody)));
  assert.equal(Object.isFrozen(revision), true);
  assert.throws(() => {
    (revision as { bodyHash: string }).bodyHash = 'x';
  });
  assert.equal(canonicalJson({ b: 1, a: [2, { d: 1, c: undefined }] }), '{"a":[2,{"d":1}],"b":1}');
});

void test('pointer activation is expected-revision guarded and keeps the previous revision', () => {
  const first = activateRevision(null, 0, id('YB'), id('YE'), now);
  assert.equal(first.revision, 1);
  assert.equal(first.previousPublishedRevisionId, null);
  const second = activateRevision(first, 1, id('YB'), id('YF'), later);
  assert.equal(second.revision, 2);
  assert.equal(second.previousPublishedRevisionId, id('YE'));
  assert.equal(
    refusalCode(() => activateRevision(first, 0, id('YB'), id('YG'), later)),
    'revision_conflict',
  );
  assert.equal(
    refusalCode(() => activateRevision(null, 3, id('YB'), id('YG'), later)),
    'revision_conflict',
  );
});
