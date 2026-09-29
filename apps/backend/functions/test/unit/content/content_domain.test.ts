import assert from 'node:assert/strict';
import test from 'node:test';

import { contentTypeIds } from '../../../src/contracts/content_v1.js';
import {
  assertBoundedBody,
  createContentDraft,
  directProvenance,
  updateContentDraftBody,
  withDraftStatus,
} from '../../../src/modules/content/domain/content_draft.js';
import {
  contentTypeRegistry,
  contentTypeRegistryRevision,
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import { ContentDomainRefusal } from '../../../src/modules/content/domain/failures.js';
import {
  activateRevision,
  applyModerationHold,
  deriveVisibility,
  isPubliclyVisible,
  restoreModerationHold,
  withdrawByOwner,
} from '../../../src/modules/content/domain/publication_pointer.js';
import {
  applyReviewDisposition,
  assertPublishable,
  createPublicationSubmission,
  withSubmissionState,
} from '../../../src/modules/content/domain/publication_submission.js';
import {
  canonicalJson,
  createPublishedRevision,
  sha256Hex,
} from '../../../src/modules/content/domain/published_revision.js';
import { validateContentContract } from '../../../src/contracts/validate_content_contract.js';
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
    provenance: directProvenance(id('YC')),
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

const expectedUnavailable: Readonly<
  Record<string, { readonly reason: string; readonly dependency: string | undefined }>
> = {
  route: { reason: 'dependency_pending', dependency: 'BCK-11' },
  scenario: { reason: 'dependency_pending', dependency: 'BCK-10' },
  find_people: { reason: 'consent_gate_pending', dependency: 'BCK-06 + OD-11' },
  session: { reason: 'spec_not_approved', dependency: 'SES-CRT-01 spec Draft' },
  class_workshop: {
    reason: 'spec_not_approved',
    dependency: 'Class/Workshop spec Ready for approval',
  },
};
/** Types whose approved source rules are implemented; grows one type per commit. */
const expectedAvailable = ['place', 'activity', 'collection', 'rental', 'event'] as const;

void test('every registry entry carries the full §33.1 policy and is frozen', () => {
  assert.equal(contentTypeRegistryRevision, 'content-type-registry-v6');
  const seen = new Set<string>();
  for (const item of contentTypeRegistry) {
    assert.equal(seen.has(item.typeId), false, `duplicate ${item.typeId}`);
    seen.add(item.typeId);
    assert.equal(item.typeSchemaMajor, 1);
    assert.ok(item.sourceAuthority.length > 0, item.typeId);
    assert.ok(item.discoverFamily.length > 0, item.typeId);
    assert.equal(item.moderationProfileId, `${item.typeId}.default`);
    assert.equal(item.mapperRevision, `${item.typeId}-mapper-v1`);
    assert.equal(item.marketPolicy, 'single_market_per_content');
    assert.equal(item.localizedTextPolicy, 'per_locale_with_declared_fallback');
    assert.deepEqual(item.allowedPublisherTypes, ['user', 'page']);
    assert.equal(item.requiredCapabilities.create, 'content.create');
    assert.equal(item.requiredCapabilities.submit, 'content.submit');
    assert.equal(item.requiredCapabilities.publish, 'content.publish');
    assert.equal(Object.isFrozen(item), true, item.typeId);
    assert.equal(Object.isFrozen(item.availability), true, item.typeId);
  }
  assert.equal(resolveContentType('find_people')?.visibilityPolicy, 'consent_limited');
  assert.equal(resolveContentType('place')?.visibilityPolicy, 'public_catalog');
  assert.equal(resolveContentType('route')?.sourceResolver, 'pinned_immutable_revision');
  assert.equal(resolveContentType('scenario')?.sourceResolver, 'pinned_immutable_revision');
  assert.equal(resolveContentType('collection')?.sourceResolver, 'published_object_membership');
});

void test('availability is explicit: rules and media extractor exist exactly when available', () => {
  for (const item of contentTypeRegistry) {
    if (isContentTypeAvailable(item)) {
      assert.ok(
        (expectedAvailable as readonly string[]).includes(item.typeId),
        `unexpected ${item.typeId}`,
      );
      assert.equal(item.availability.status, 'available');
      assert.equal(typeof item.validate, 'function');
      assert.equal(typeof item.mediaIds, 'function');
      assert.equal(item.validatorRevision, `${item.typeId}-source-v1`);
    } else {
      const expected = expectedUnavailable[item.typeId];
      assert.ok(expected, `unexpected unavailable ${item.typeId}`);
      assert.equal(item.validate, undefined, item.typeId);
      assert.equal(item.mediaIds, undefined, item.typeId);
      assert.equal(item.validatorRevision, 'unavailable');
      assert.equal(item.availability.status, 'unavailable');
      if (item.availability.status === 'unavailable') {
        assert.equal(item.availability.reason, expected.reason, item.typeId);
        assert.equal(item.availability.dependency, expected.dependency, item.typeId);
      }
    }
  }
});

void test('the available set is exactly the implemented approved types', () => {
  assert.deepEqual(
    contentTypeRegistry
      .filter(isContentTypeAvailable)
      .map((item) => item.typeId)
      .sort(),
    [...expectedAvailable].sort(),
  );
  assert.equal(
    contentTypeRegistry.filter((item) => !isContentTypeAvailable(item)).length,
    10 - expectedAvailable.length,
  );
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

// ---------------------------------------------------------------------------
// 2.3 lifecycle: pointer holds and review dispositions (pure domain)
// ---------------------------------------------------------------------------

const revA = id('YE');
const revB = id('YF');
const t0 = now;
const t1 = later;

function firstPointer() {
  return activateRevision(null, 0, id('YB'), revA, t0);
}

void test('visibility is derived: a moderation hold always outranks an owner hold', () => {
  assert.equal(deriveVisibility(null, null), 'visible');
  assert.equal(deriveVisibility('withdrawn', null), 'withdrawn');
  assert.equal(deriveVisibility('archived', null), 'archived');
  assert.equal(deriveVisibility(null, { kind: 'restricted', decisionId: 'd' }), 'restricted');
  assert.equal(deriveVisibility('archived', { kind: 'withdrawn', decisionId: 'd' }), 'withdrawn');
  assert.equal(isPubliclyVisible(null), false);
  assert.equal(isPubliclyVisible(firstPointer()), true);
});

void test('owner withdraw/archive needs the observed pointer revision and works once', () => {
  const pointer = firstPointer();
  const archived = withdrawByOwner(pointer, 1, 'archive', t1);
  assert.equal(archived.visibility, 'archived');
  assert.equal(archived.ownerHold, 'archived');
  assert.equal(archived.revision, 2);
  assert.equal(archived.currentPublishedRevisionId, revA);
  assert.equal(pointer.revision, 1);
  assert.equal(
    refusalCode(() => withdrawByOwner(pointer, 9, 'withdraw', t1)),
    'revision_conflict',
  );
  assert.equal(
    refusalCode(() => withdrawByOwner(archived, 2, 'withdraw', t1)),
    'revision_conflict',
  );
  assert.equal(
    refusalCode(() => withdrawByOwner(null, 0, 'withdraw', t1)),
    'not_found',
  );
});

void test('activation lifts an owner hold but can never bypass a moderation hold', () => {
  const owner = withdrawByOwner(firstPointer(), 1, 'withdraw', t0);
  const lifted = activateRevision(owner, 2, id('YB'), revB, t1);
  assert.equal(lifted.visibility, 'visible');
  assert.equal(lifted.ownerHold, null);
  assert.equal(lifted.previousPublishedRevisionId, revA);
  const held = applyModerationHold(firstPointer(), revA, 'restricted', 'dec-1', t1);
  assert.equal(
    refusalCode(() => activateRevision(held, 2, id('YB'), revB, t1)),
    'publication_restricted',
  );
  assert.equal(held.moderationHold?.decisionId, 'dec-1');
});

void test('re-selecting the current revision never makes it its own predecessor', () => {
  const second = activateRevision(firstPointer(), 1, id('YB'), revB, t1);
  const withdrawn = withdrawByOwner(second, 2, 'withdraw', t1);
  const again = activateRevision(withdrawn, 3, id('YB'), revB, t1);
  assert.equal(again.currentPublishedRevisionId, revB);
  assert.equal(again.previousPublishedRevisionId, revA);
});

void test('moderation holds target the exact revision and never weaken a stronger hold', () => {
  const pointer = firstPointer();
  assert.equal(
    refusalCode(() => applyModerationHold(pointer, revB, 'restricted', 'd', t1)),
    'moderation_decision_stale',
  );
  assert.equal(
    refusalCode(() => applyModerationHold(null, revA, 'restricted', 'd', t1)),
    'not_found',
  );
  const restricted = applyModerationHold(pointer, undefined, 'restricted', 'dec-1', t1);
  const withdrawn = applyModerationHold(restricted, revA, 'withdrawn', 'dec-2', t1);
  assert.equal(withdrawn.moderationHold?.kind, 'withdrawn');
  assert.equal(withdrawn.revision, 3);
  assert.equal(
    refusalCode(() => applyModerationHold(withdrawn, revA, 'restricted', 'dec-3', t1)),
    'moderation_decision_stale',
  );
  // A newer decision of the same strength replaces the chain.
  const replaced = applyModerationHold(restricted, revA, 'restricted', 'dec-9', t1);
  assert.equal(replaced.moderationHold?.decisionId, 'dec-9');
});

void test('restore lifts exactly the named decision and leaves the owner hold alone', () => {
  const owner = withdrawByOwner(firstPointer(), 1, 'archive', t0);
  const both = applyModerationHold(owner, revA, 'restricted', 'dec-1', t1);
  assert.equal(both.visibility, 'restricted');
  assert.equal(both.ownerHold, 'archived');
  assert.equal(
    refusalCode(() => restoreModerationHold(both, 'dec-other', t1)),
    'moderation_decision_stale',
  );
  assert.equal(
    refusalCode(() => restoreModerationHold(null, 'dec-1', t1)),
    'not_found',
  );
  const restored = restoreModerationHold(both, 'dec-1', t1);
  assert.equal(restored.moderationHold, null);
  assert.equal(restored.visibility, 'archived');
  assert.equal(restored.ownerHold, 'archived');
  assert.equal(
    refusalCode(() => restoreModerationHold(restored, 'dec-1', t1)),
    'moderation_decision_stale',
  );
});

void test('pointer states satisfy the contract schema', async () => {
  const states = [
    firstPointer(),
    withdrawByOwner(firstPointer(), 1, 'archive', t1),
    applyModerationHold(firstPointer(), revA, 'withdrawn', 'dec-1', t1),
    applyModerationHold(
      withdrawByOwner(firstPointer(), 1, 'withdraw', t0),
      revA,
      'restricted',
      'dec-2',
      t1,
    ),
  ];
  for (const state of states)
    assert.equal(
      (await validateContentContract('publicationPointer', state)).ok,
      true,
      state.visibility,
    );
});

void test('review dispositions apply only to a submission that is still under review', () => {
  const created = draft();
  const submission = (requiresReview: boolean) =>
    createPublicationSubmission({
      submissionId: id('YD'),
      draft: created,
      moderation: {
        profileId: 'place.default',
        requiresPrePublicationModeration: requiresReview,
        policyRevision: 'p1',
        ...(requiresReview ? {} : { policyDecisionId: 'pd-1' }),
      },
      eligibilityAuthorityRevision: 1,
      referenceRevisions: references,
      nowUtc: now,
    });
  const review = submission(true);
  const approved = applyReviewDisposition(review, 'approve', 'dec-1', t1);
  assert.equal(approved.state, 'approved_for_publication');
  assert.equal(approved.moderation.policyDecisionId, 'dec-1');
  assert.equal(applyReviewDisposition(review, 'reject', 'dec-2', t1).state, 'rejected');
  assert.equal(
    applyReviewDisposition(review, 'request_revision', 'dec-3', t1).state,
    'revision_requested',
  );
  assert.equal(review.state, 'under_review');
  // Approved, rejected and unmoderated submissions cannot be decided again.
  for (const settled of [approved, submission(false)])
    assert.equal(
      refusalCode(() => applyReviewDisposition(settled, 'reject', 'dec-4', t1)),
      'moderation_decision_stale',
    );
});
