import assert from 'node:assert/strict';
import test from 'node:test';

import {
  contentTypeIds,
  type ContentTypeId,
  type PublishedRevisionV1,
} from '../../src/contracts/content_v1.js';
import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import {
  ContentPublicationService,
  type ContentIdGenerator,
} from '../../src/modules/content/application/content_publication_service.js';
import type {
  ContentActor,
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import type { MediaReadinessPort } from '../../src/modules/content/application/ports/media_readiness_port.js';
import type { ModerationDispositionPort } from '../../src/modules/content/application/ports/moderation_disposition_port.js';
import type { ReferenceDataPort } from '../../src/modules/content/application/ports/reference_data_port.js';
import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../src/modules/content/domain/content_type_registry.js';
import { toContentWireResult } from '../../src/modules/content/domain/failures.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { validateContentContract } from '../../src/contracts/validate_content_contract.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { FakeClock } from '../support/fake_clock.js';

const crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
function ulid(counter: number): EntityId {
  let rest = counter;
  let suffix = '';
  for (let index = 0; index < 8; index += 1) {
    suffix = crockford[rest % 32] + suffix;
    rest = Math.floor(rest / 32);
  }
  return parseEntityId(`01HZZZZZZZZZZZZZZZ${suffix}`);
}

class SequentialIds implements ContentIdGenerator {
  #next = 1000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = ulid(1);
const userB = ulid(2);
const pageA = ulid(3);
const sessionA = ulid(4);
const sessionB = ulid(5);
const actorA: ContentActor = { userId: userA, sessionId: sessionA };
const actorB: ContentActor = { userId: userB, sessionId: sessionB };

class FakeEligibility implements PublisherEligibilityPort {
  readonly requests: PublisherEligibilityRequest[] = [];
  deny: PublisherEligibilityV1['reason'] | undefined;
  wrongPublisher = false;
  evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    this.requests.push(request);
    const eligible = this.deny === undefined;
    return Promise.resolve({
      schemaVersion: 1,
      publisherRef: this.wrongPublisher ? { type: 'user', id: ulid(999) } : request.publisherRef,
      eligible,
      reason: this.deny ?? 'eligible',
      authorityRevision: 7,
      evaluatedAtUtc: request.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    });
  }
}

class FakeReferenceData implements ReferenceDataPort {
  marketDisabled = false;
  revision = 'mc-lv-1';
  resolve() {
    return Promise.resolve(
      this.marketDisabled
        ? ({ ok: false, code: 'market_disabled' } as const)
        : ({
            ok: true,
            revisions: {
              marketConfigRevisionId: this.revision,
              taxonomyRevisionId: 'tx-1',
              localizationRevisionId: 'loc-1',
            },
            market: marketContext,
            lookups: referenceLookups,
          } as const),
    );
  }
}

class FakeModeration implements ModerationDispositionPort {
  requiresReview = false;
  available = true;
  profileFor() {
    return Promise.resolve(
      this.available
        ? ({
            available: true,
            profileId: 'place.default',
            requiresPrePublicationModeration: this.requiresReview,
            policyRevision: 'pol-1',
            ...(this.requiresReview ? {} : { policyDecisionId: 'pd-1' }),
          } as const)
        : ({ available: false } as const),
    );
  }
}

class FakeMedia implements MediaReadinessPort {
  ready = true;
  check() {
    return Promise.resolve(
      this.ready
        ? ({ ready: true, mediaRevision: 'media-1' } as const)
        : ({ ready: false } as const),
    );
  }
}

const placeBody = {
  title: 'Vermanes garden greenhouse',
  placeKind: 'managedVenue',
  relationshipToPlace: 'owner',
  shortDescription: 'Historic glass greenhouse in the city centre',
  contentLocale: 'en',
  categoryId: 'art_culture_museums',
  subcategoryId: 'museum',
  location: {
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    formattedAddress: 'Elizabetes iela 1, Riga',
    point: { latitude: 56.9496, longitude: 24.1052 },
    timezoneId: 'Europe/Riga',
    accuracy: 'rooftop',
    pinConfirmed: true,
  },
  hours: {
    mode: 'regular',
    weeklyPeriods: [
      { id: 'period-1', dayOfWeek: 1, openMinute: 600, closeMinute: 1140, closesNextDay: false },
    ],
    seasons: [],
    exceptions: [],
  },
  operationalStatus: { status: 'operating' },
  pricing: { entryType: 'paid', entryPriceFrom: 700, currencyCode: 'EUR' },
  media: { coverImage: { mediaId: 'media-cover' }, gallery: [] },
  provenance: {
    sourceType: 'ownerSubmission',
    submittedByUserId: userA,
    relationshipClaim: 'owner',
    createdAtUtc: '2026-09-29T09:00:00.000Z',
    lastConfirmedAtUtc: '2026-09-29T09:00:00.000Z',
  },
};

const referenceLookups = {
  supportsLocale: (locale: string) => ['en', 'ru', 'lv'].includes(locale),
  subcategoryApplies: () => true,
  requiredCriteria: () => [] as readonly string[],
  pointInServiceArea: (latitude: number, longitude: number) =>
    latitude > 56 && latitude < 58 && longitude > 23 && longitude < 25.5,
};
const marketContext = { currencyCode: 'EUR', timezoneId: 'Europe/Riga' } as const;

function harness(enabled: readonly ContentTypeId[] = ['place']) {
  const repository = new InMemoryContentRepository();
  const eligibility = new FakeEligibility();
  const referenceData = new FakeReferenceData();
  const moderation = new FakeModeration();
  const media = new FakeMedia();
  const clock = new FakeClock(new Date('2026-09-29T10:00:00.000Z'));
  const service = new ContentPublicationService({
    repository,
    eligibility,
    referenceData,
    moderation,
    media,
    clock,
    ids: new SequentialIds(),
    enabledTypes: new Set(enabled),
  });
  return { service, repository, eligibility, referenceData, moderation, media, clock };
}

let keyCounter = 0;
const key = (label: string) => `${label}-${String((keyCounter += 1)).padStart(6, '0')}`;

const createCommand = (
  overrides: Record<string, unknown> = {},
  idempotencyKey = key('create'),
) => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey,
  payload: {
    typeId: 'place',
    publisherRef: { type: 'user', id: userA },
    marketId: 'LV',
    body: placeBody,
    ...overrides,
  },
});
const updateCommand = (
  draftId: string,
  expectedRevision: number,
  body: unknown,
  idempotencyKey = key('update'),
) => ({
  schemaVersion: 1,
  commandType: 'updateDraft',
  idempotencyKey,
  payload: { draftId, expectedRevision, body },
});
const submitCommand = (
  draftId: string,
  expectedDraftRevision: number,
  idempotencyKey = key('submit'),
) => ({
  schemaVersion: 1,
  commandType: 'submitForPublication',
  idempotencyKey,
  payload: { draftId, expectedDraftRevision },
});
const publishCommand = (
  submissionId: string,
  expectedPointerRevision: number,
  idempotencyKey = key('publish'),
) => ({
  schemaVersion: 1,
  commandType: 'publishApprovedRevision',
  idempotencyKey,
  payload: { submissionId, expectedPointerRevision },
});

async function data<T>(
  promise: Promise<{ kind: string; data?: unknown; code?: string }>,
): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', `unexpected ${result.kind}:${String(result.code)}`);
  return result.data as T;
}

interface DraftLike {
  draftId: EntityId;
  contentId: EntityId;
  revision: number;
  status: string;
}
interface SubmissionLike {
  submissionId: EntityId;
  state: string;
}

void test('Place flows draft -> submit -> publish with an immutable revision, pointer, audit and effect', async () => {
  const { service, repository, eligibility } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  assert.equal(draft.revision, 1);
  assert.match(draft.draftId, /^[0-9A-HJKMNP-TV-Z]{26}$/);
  const updated = await data<DraftLike>(
    service.execute(
      actorA,
      updateCommand(draft.draftId, 1, {
        ...placeBody,
        shortDescription: 'A restored glass house in the old garden',
      }),
    ),
  );
  assert.equal(updated.revision, 2);
  const submission = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 2)),
  );
  assert.equal(submission.state, 'approved_for_publication');
  const revision = await data<PublishedRevisionV1>(
    service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  assert.equal(revision.revisionNumber, 1);
  assert.equal(revision.referenceRevisions.marketConfigRevisionId, 'mc-lv-1');
  assert.equal(revision.mediaRevision, 'media-1');
  assert.deepEqual(revision.publisherRef, { type: 'user', id: userA });

  const snapshot = repository.snapshot();
  assert.equal(snapshot.pointers.length, 1);
  assert.equal(snapshot.pointers[0]?.revision, 1);
  assert.equal(snapshot.pointers[0]?.currentPublishedRevisionId, revision.publishedRevisionId);
  assert.equal(snapshot.effects.length, 1);
  assert.equal(snapshot.effects[0]?.kind, 'ContentPublished');
  assert.equal(JSON.stringify(snapshot.effects).includes('Glass house'), false);
  assert.deepEqual(
    snapshot.audit.map((entry) => entry.action),
    [
      'content.draft.created',
      'content.draft.updated',
      'content.publication.submitted',
      'content.publication.published',
    ],
  );
  // Authority was re-evaluated for every command with the exact action.
  assert.deepEqual(
    eligibility.requests.map((request) => request.action),
    ['create', 'update', 'submit', 'publish'],
  );

  const status = await data<{ pointer: { visibility: string } }>(
    service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getPublicationStatus',
      payload: { contentId: draft.contentId },
    }),
  );
  assert.equal(status.pointer.visibility, 'visible');
  const published = await data<PublishedRevisionV1>(
    service.query(actorB, {
      schemaVersion: 1,
      queryType: 'getPublishedRevision',
      payload: { contentId: draft.contentId },
    }),
  );
  assert.equal(published.publishedRevisionId, revision.publishedRevisionId);
});

void test('every result satisfies the wire result schema', async () => {
  const { service } = harness();
  const success = await service.execute(actorA, createCommand());
  const failure = await service.execute(actorA, { ...createCommand(), schemaVersion: 2 });
  const rejection = await service.execute(undefined, createCommand());
  for (const result of [success, failure, rejection])
    assert.equal(
      (await validateContentContract('result', toContentWireResult('draft', result))).ok,
      true,
      result.kind,
    );
});

void test('all ten types are explicit; unknown types and Quick Plan fail closed without fallback', async () => {
  const { service } = harness([...contentTypeIds]);
  for (const typeId of contentTypeIds.filter((id) => {
    const entry = resolveContentType(id);
    return entry === null || !isContentTypeAvailable(entry);
  })) {
    const result = await service.execute(actorA, createCommand({ typeId }));
    assert.deepEqual(result, { kind: 'rejected', code: 'content_type_unsupported' }, typeId);
  }
  for (const typeId of ['quick_plan', 'place_v2', 'EVENT']) {
    const result = await service.execute(actorA, createCommand({ typeId }));
    assert.deepEqual(
      result,
      { kind: 'unsupportedContract', code: 'content_type_unsupported' },
      typeId,
    );
  }
  const disabled = harness([]);
  assert.deepEqual(await disabled.service.execute(actorA, createCommand()), {
    kind: 'rejected',
    code: 'type_disabled',
  });
  assert.equal(disabled.repository.snapshot().drafts.length, 0);
});

void test('unauthenticated, newer schema and malformed commands create no state', async () => {
  const { service, repository } = harness();
  assert.deepEqual(await service.execute(undefined, createCommand()), {
    kind: 'rejected',
    code: 'unauthenticated',
  });
  assert.deepEqual(await service.execute(actorA, { ...createCommand(), schemaVersion: 2 }), {
    kind: 'unsupportedContract',
    code: 'unsupported_version',
  });
  assert.deepEqual(await service.execute(actorA, { ...createCommand(), extra: true }), {
    kind: 'rejected',
    code: 'invalid_contract',
  });
  assert.deepEqual(await service.execute(actorA, 'nonsense'), {
    kind: 'rejected',
    code: 'invalid_contract',
  });
  assert.deepEqual(await service.execute(actorA, createCommand({ importSourceKey: 'not-loc' })), {
    kind: 'rejected',
    code: 'invalid_contract',
  });
  assert.equal(repository.snapshot().drafts.length, 0);
});

void test('semantic idempotency replays equal commands and rejects a changed payload under the same key', async () => {
  const { service, repository } = harness();
  const command = createCommand({}, 'idem-key-0001');
  const first = await data<DraftLike>(service.execute(actorA, command));
  const replay = await data<DraftLike>(service.execute(actorA, command));
  assert.equal(replay.draftId, first.draftId);
  assert.equal(repository.snapshot().drafts.length, 1);
  const conflicting = createCommand({ body: { ...placeBody, title: 'Other' } }, 'idem-key-0001');
  assert.deepEqual(await service.execute(actorA, conflicting), {
    kind: 'rejected',
    code: 'idempotency_conflict',
  });
  // The same key from another actor is an independent logical mutation.
  const other = await data<DraftLike>(service.execute(actorB, command));
  assert.notEqual(other.draftId, first.draftId);
  assert.equal(repository.snapshot().drafts.length, 2);
});

void test('key order does not change the semantic hash', async () => {
  const { service } = harness();
  const a = createCommand({}, 'idem-key-0002');
  const b = {
    idempotencyKey: 'idem-key-0002',
    payload: {
      body: { ...placeBody },
      marketId: 'LV',
      publisherRef: { id: userA, type: 'user' },
      typeId: 'place',
    },
    commandType: 'createDraft',
    schemaVersion: 1,
  };
  const first = await data<DraftLike>(service.execute(actorA, a));
  const second = await data<DraftLike>(service.execute(actorA, b));
  assert.equal(second.draftId, first.draftId);
});

void test('stale draft revisions are rejected and a submitted draft cannot be edited', async () => {
  const { service } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  assert.deepEqual(await service.execute(actorA, updateCommand(draft.draftId, 9, placeBody)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  assert.deepEqual(await service.execute(actorA, submitCommand(draft.draftId, 9)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  await data<SubmissionLike>(service.execute(actorA, submitCommand(draft.draftId, 1)));
  assert.deepEqual(await service.execute(actorA, updateCommand(draft.draftId, 1, placeBody)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  assert.deepEqual(await service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
});

void test('incomplete drafts are storable but cannot be submitted', async () => {
  const { service, repository } = harness();
  const draft = await data<DraftLike>(
    service.execute(actorA, createCommand({ body: { title: 'only a title' } })),
  );
  assert.deepEqual(await service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'validation_failed',
  });
  assert.equal(repository.snapshot().submissions.length, 0);
  assert.deepEqual(await service.execute(actorA, createCommand({ body: [] })), {
    kind: 'rejected',
    code: 'invalid_contract',
  });
});

void test('media, moderation profile and market gates stop submit and publish', async () => {
  const gates = harness();
  const draft = await data<DraftLike>(gates.service.execute(actorA, createCommand()));
  gates.media.ready = false;
  assert.deepEqual(await gates.service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'media_not_ready',
  });
  gates.media.ready = true;
  gates.moderation.available = false;
  assert.deepEqual(await gates.service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'policy_unavailable',
  });
  gates.moderation.available = true;
  gates.referenceData.marketDisabled = true;
  assert.deepEqual(await gates.service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'market_disabled',
  });
  gates.referenceData.marketDisabled = false;
  const submission = await data<SubmissionLike>(
    gates.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  gates.referenceData.marketDisabled = true;
  assert.deepEqual(
    await gates.service.execute(actorA, publishCommand(submission.submissionId, 0)),
    { kind: 'rejected', code: 'market_disabled' },
  );
  assert.equal(gates.repository.snapshot().pointers.length, 0);
});

void test('a type requiring review cannot publish before an approval exists', async () => {
  const { service, moderation, repository } = harness();
  moderation.requiresReview = true;
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  assert.equal(submission.state, 'under_review');
  assert.deepEqual(await service.execute(actorA, publishCommand(submission.submissionId, 0)), {
    kind: 'rejected',
    code: 'moderation_required',
  });
  assert.equal(repository.snapshot().revisions.length, 0);
});

void test('a failed publish rolls back completely and can be retried', async () => {
  const { service, repository, media } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  media.ready = false;
  const command = publishCommand(submission.submissionId, 0, 'publish-retry-1');
  assert.deepEqual(await service.execute(actorA, command), {
    kind: 'rejected',
    code: 'media_not_ready',
  });
  let snapshot = repository.snapshot();
  assert.equal(snapshot.revisions.length, 0);
  assert.equal(snapshot.pointers.length, 0);
  assert.equal(snapshot.effects.length, 0);
  assert.equal(
    snapshot.audit.some((entry) => entry.action === 'content.publication.published'),
    false,
  );
  media.ready = true;
  const revision = await data<PublishedRevisionV1>(service.execute(actorA, command));
  assert.equal(revision.revisionNumber, 1);
  snapshot = repository.snapshot();
  assert.equal(snapshot.revisions.length, 1);
  assert.equal(snapshot.effects.length, 1);
});

void test('a second revision supersedes the first without touching immutable history', async () => {
  const { service, repository } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  const first = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const firstRevision = await data<PublishedRevisionV1>(
    service.execute(actorA, publishCommand(first.submissionId, 0)),
  );
  const after = await data<DraftLike>(
    service.execute(
      actorA,
      updateCommand(draft.draftId, 1, { ...placeBody, title: 'Second title' }),
    ),
  );
  assert.equal(after.revision, 2);
  const second = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 2)),
  );
  // A publish against a stale pointer revision must not switch visibility.
  assert.deepEqual(await service.execute(actorA, publishCommand(second.submissionId, 0)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  const secondRevision = await data<PublishedRevisionV1>(
    service.execute(actorA, publishCommand(second.submissionId, 1)),
  );
  assert.equal(secondRevision.revisionNumber, 2);
  const snapshot = repository.snapshot();
  assert.equal(snapshot.pointers[0]?.revision, 2);
  assert.equal(
    snapshot.pointers[0]?.previousPublishedRevisionId,
    firstRevision.publishedRevisionId,
  );
  const stored = snapshot.revisions.find(
    (item) => item.publishedRevisionId === firstRevision.publishedRevisionId,
  );
  assert.equal(stored?.body.title, 'Vermanes garden greenhouse');
  assert.equal(snapshot.effects.at(-1)?.kind, 'ContentRevisionActivated');
  assert.deepEqual(snapshot.submissions.map((item) => item.state).sort(), [
    'published',
    'superseded',
  ]);
});

void test('concurrent duplicate publishes create exactly one revision', async () => {
  const { service, repository } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const results = await Promise.all([
    service.execute(actorA, publishCommand(submission.submissionId, 0, 'concurrent-key-1')),
    service.execute(actorA, publishCommand(submission.submissionId, 0, 'concurrent-key-2')),
  ]);
  assert.equal(results.filter((item) => item.kind === 'succeeded').length, 1);
  assert.equal(results.filter((item) => item.kind === 'rejected').length, 1);
  const snapshot = repository.snapshot();
  assert.equal(snapshot.revisions.length, 1);
  assert.equal(snapshot.pointers[0]?.revision, 1);
  assert.equal(snapshot.effects.length, 1);
});

void test('editing a draft after publish does not change the visible revision until republished', async () => {
  const { service } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const revision = await data<PublishedRevisionV1>(
    service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  await data<DraftLike>(
    service.execute(
      actorA,
      updateCommand(draft.draftId, 1, { ...placeBody, title: 'Work in progress' }),
    ),
  );
  const visible = await data<PublishedRevisionV1>(
    service.query(actorB, {
      schemaVersion: 1,
      queryType: 'getPublishedRevision',
      payload: { contentId: draft.contentId },
    }),
  );
  assert.equal(visible.publishedRevisionId, revision.publishedRevisionId);
  assert.equal(visible.body.title, 'Vermanes garden greenhouse');
});

void test('an already published submission cannot be published again', async () => {
  const { service } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  // The `source_revision_stale` guard (draft ahead of an approved submission)
  // is defensive: it becomes reachable through public commands only once
  // moderation dispositions land (BCK07 2.3).
  await data<PublishedRevisionV1>(
    service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  assert.deepEqual(await service.execute(actorA, publishCommand(submission.submissionId, 1)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
});

void test('authority is re-evaluated with the exact action and a foreign answer is never accepted', async () => {
  const { service, eligibility, repository } = harness();
  eligibility.wrongPublisher = true;
  assert.deepEqual(await service.execute(actorA, createCommand()), {
    kind: 'rejected',
    code: 'publisher_not_eligible',
  });
  eligibility.wrongPublisher = false;
  const reasons: Array<[PublisherEligibilityV1['reason'], string]> = [
    ['creator_verification_required', 'creator_verification_required'],
    ['membership_inactive', 'membership_inactive'],
    ['capability_denied', 'capability_denied'],
    ['publisher_not_accessible', 'publisher_not_eligible'],
    ['snapshot_stale', 'publisher_not_eligible'],
    ['account_inactive', 'publisher_not_eligible'],
  ];
  for (const [reason, code] of reasons) {
    eligibility.deny = reason;
    assert.deepEqual(
      await service.execute(actorA, createCommand()),
      { kind: 'rejected', code },
      reason,
    );
  }
  assert.equal(repository.snapshot().drafts.length, 0);
});

void test('imported loc_* keys stay provenance and the draft gets a permanent id', async () => {
  const { service } = harness();
  const draft = await data<DraftLike & { importSourceKey: string }>(
    service.execute(actorA, createCommand({ importSourceKey: 'loc_local-draft-1' })),
  );
  assert.equal(draft.importSourceKey, 'loc_local-draft-1');
  assert.equal(draft.draftId.startsWith('loc_'), false);
  assert.equal(draft.contentId.startsWith('loc_'), false);
});

void test('page publishers keep their immutable binding origin', async () => {
  const { service } = harness();
  const draft = await data<{
    publisherRef: unknown;
    publisherBindingOrigin: unknown;
    draftId: string;
  }>(service.execute(actorA, createCommand({ publisherRef: { type: 'page', id: pageA } })));
  assert.deepEqual(draft.publisherRef, { type: 'page', id: pageA });
  assert.deepEqual(draft.publisherBindingOrigin, draft.publisherRef);
});

void test('queries of unknown content and unpublished content return not_found', async () => {
  const { service } = harness();
  assert.deepEqual(
    await service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getPublishedRevision',
      payload: { contentId: ulid(77) },
    }),
    { kind: 'rejected', code: 'not_found' },
  );
  assert.deepEqual(
    await service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: ulid(78) },
    }),
    { kind: 'rejected', code: 'not_found' },
  );
  assert.deepEqual(
    await service.query(undefined, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: ulid(78) },
    }),
    {
      kind: 'rejected',
      code: 'unauthenticated',
    },
  );
  assert.deepEqual(
    await service.query(actorA, {
      schemaVersion: 2,
      queryType: 'getDraft',
      payload: { draftId: ulid(78) },
    }),
    {
      kind: 'unsupportedContract',
      code: 'unsupported_version',
    },
  );
});

async function replaceStoredDraft(
  repository: InMemoryContentRepository,
  draftId: string,
  change: Record<string, unknown>,
): Promise<void> {
  await repository.transact(async (tx) => {
    const stored = await tx.draft(draftId);
    assert.ok(stored);
    tx.putDraft({ ...structuredClone(stored), ...change });
  });
}

void test('stored records of an unavailable type fail closed on every later command', async () => {
  const { service, repository } = harness([...contentTypeIds]);
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  await replaceStoredDraft(repository, draft.draftId, { typeId: 'event' });
  assert.deepEqual(await service.execute(actorA, updateCommand(draft.draftId, 1, placeBody)), {
    kind: 'rejected',
    code: 'content_type_unsupported',
  });
  assert.deepEqual(await service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'content_type_unsupported',
  });
  assert.equal(repository.snapshot().submissions.length, 0);
});

void test('a stored draft from a newer type schema major is never coerced', async () => {
  const { service, repository } = harness();
  const draft = await data<DraftLike>(service.execute(actorA, createCommand()));
  await replaceStoredDraft(repository, draft.draftId, { typeSchemaMajor: 2 });
  assert.deepEqual(await service.execute(actorA, updateCommand(draft.draftId, 1, placeBody)), {
    kind: 'rejected',
    code: 'unsupported_version',
  });
  assert.deepEqual(await service.execute(actorA, submitCommand(draft.draftId, 1)), {
    kind: 'rejected',
    code: 'unsupported_version',
  });
  assert.equal(repository.snapshot().submissions.length, 0);
});

void test('a type disabled after submit cannot be published', async () => {
  const first = harness();
  const draft = await data<DraftLike>(first.service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    first.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const disabled = new ContentPublicationService({
    repository: first.repository,
    eligibility: first.eligibility,
    referenceData: first.referenceData,
    moderation: first.moderation,
    media: first.media,
    clock: first.clock,
    ids: new SequentialIds(),
    enabledTypes: new Set<ContentTypeId>(),
  });
  assert.deepEqual(await disabled.execute(actorA, publishCommand(submission.submissionId, 0)), {
    kind: 'rejected',
    code: 'type_disabled',
  });
  assert.equal(first.repository.snapshot().revisions.length, 0);
});
