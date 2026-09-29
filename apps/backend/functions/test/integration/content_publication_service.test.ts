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
import {
  toContentWireResult,
  type ContentResult,
  type ContentResultType,
} from '../../src/modules/content/domain/failures.js';
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
  /** Issuer the fake decision authority vouches for; undefined = nobody. */
  issuer: string | undefined = 'bck22';
  verifyDisposition(input: { readonly payload: { readonly attestation: string } }) {
    return Promise.resolve(
      input.payload.attestation.startsWith('valid-') && this.issuer !== undefined
        ? ({ verified: true, issuer: this.issuer } as const)
        : ({ verified: false } as const),
    );
  }
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
  await replaceStoredDraft(repository, draft.draftId, { typeId: 'session' });
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

// ---------------------------------------------------------------------------
// 2.3 Publication lifecycle: moderation dispositions, withdraw/archive, restore
// and compatible rollback.
// ---------------------------------------------------------------------------

interface PointerLike {
  contentId: EntityId;
  revision: number;
  visibility: string;
  ownerHold: string | null;
  moderationHold: { kind: string; decisionId: string } | null;
  currentPublishedRevisionId: EntityId | null;
  previousPublishedRevisionId: EntityId | null;
}

interface AckLike {
  outcome: string;
  decisionId: string;
  pointerRevision: number | null;
}

const validAttestation = 'valid-attestation-token';

function dispositionCommand(
  kind: string,
  target: Record<string, unknown>,
  decisionId = 'dec-0001',
  extra: Record<string, unknown> = {},
) {
  return {
    schemaVersion: 1,
    commandType: 'applyModerationDisposition',
    idempotencyKey: `${decisionId}-key-01`,
    payload: {
      instructionId: `ins-${decisionId}`,
      decisionId,
      policyRevision: 'pol-1',
      disposition: kind,
      target,
      reasonCategory: 'policy_violation',
      effectiveAtUtc: '2026-09-29T09:00:00.000Z',
      attestation: validAttestation,
      ...extra,
    },
  };
}

const withdrawCommand = (
  contentId: string,
  expectedPointerRevision: number,
  mode: 'withdraw' | 'archive' = 'withdraw',
  idempotencyKey = key('withdraw'),
) => ({
  schemaVersion: 1,
  commandType: 'withdrawPublication',
  idempotencyKey,
  payload: { contentId, expectedPointerRevision, mode },
});

const activateCommand = (
  contentId: string,
  publishedRevisionId: string,
  expectedPointerRevision: number,
) => ({
  schemaVersion: 1,
  commandType: 'activatePublishedRevision',
  idempotencyKey: key('activate'),
  payload: { contentId, publishedRevisionId, expectedPointerRevision },
});

const publicRead = (service: ContentPublicationService, contentId: string) =>
  service.query(actorB, {
    schemaVersion: 1,
    queryType: 'getPublishedRevision',
    payload: { contentId },
  });

/** Publishes revision 1 of a Place with no pre-publication review. */
async function published(h: ReturnType<typeof harness>) {
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const revision = await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  return { draft, submission, revision, contentId: draft.contentId };
}

function pointerOf(h: ReturnType<typeof harness>): PointerLike {
  const pointer = h.repository.snapshot().pointers[0];
  assert.ok(pointer);
  return pointer;
}

void test('a moderated submission cannot publish until BCK-22 approves that exact submission', async () => {
  const h = harness();
  h.moderation.requiresReview = true;
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  assert.equal(submission.state, 'under_review');
  assert.deepEqual(await h.service.execute(actorA, publishCommand(submission.submissionId, 0)), {
    kind: 'rejected',
    code: 'moderation_required',
  });
  const ack = await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('approve', {
        contentId: draft.contentId,
        submissionId: submission.submissionId,
      }),
    ),
  );
  assert.equal(ack.outcome, 'applied');
  const stored = h.repository.snapshot().submissions[0];
  assert.equal(stored?.state, 'approved_for_publication');
  assert.equal(stored?.moderation.policyDecisionId, 'dec-0001');
  // Approval does not publish by itself: publication still re-checks everything.
  assert.equal(h.repository.snapshot().revisions.length, 0);
  const revision = await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  assert.equal(revision.revisionNumber, 1);
});

void test('a client can never issue or self-approve a moderation disposition', async () => {
  const h = harness();
  h.moderation.requiresReview = true;
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const forged = dispositionCommand('approve', {
    contentId: draft.contentId,
    submissionId: submission.submissionId,
  });
  assert.deepEqual(await h.service.execute(actorA, forged), {
    kind: 'rejected',
    code: 'capability_denied',
  });
  assert.equal(h.repository.snapshot().submissions[0]?.state, 'under_review');
  assert.deepEqual(await h.service.execute(actorA, publishCommand(submission.submissionId, 0)), {
    kind: 'rejected',
    code: 'moderation_required',
  });
});

void test('request_revision returns the draft to its author; the old submission cannot publish', async () => {
  const h = harness();
  h.moderation.requiresReview = true;
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('request_revision', {
        contentId: draft.contentId,
        submissionId: submission.submissionId,
      }),
    ),
  );
  const snapshot = h.repository.snapshot();
  assert.equal(snapshot.submissions[0]?.state, 'revision_requested');
  assert.equal(snapshot.drafts[0]?.status, 'revision_requested');
  assert.deepEqual(await h.service.execute(actorA, publishCommand(submission.submissionId, 0)), {
    kind: 'rejected',
    code: 'moderation_decision_stale',
  });
  // The author revises and resubmits a new candidate.
  const revised = await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(draft.draftId, 1, { ...placeBody, title: 'Revised title' }),
    ),
  );
  assert.equal(revised.status, 'editing');
  const resubmitted = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(draft.draftId, 2)),
  );
  assert.notEqual(resubmitted.submissionId, submission.submissionId);
});

void test('reject closes only that submission and leaves the published revision untouched', async () => {
  const h = harness();
  const first = await published(h);
  h.moderation.requiresReview = true;
  await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(first.draft.draftId, 1, { ...placeBody, title: 'Next' }),
    ),
  );
  const candidate = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(first.draft.draftId, 2)),
  );
  await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('reject', {
        contentId: first.contentId,
        submissionId: candidate.submissionId,
      }),
    ),
  );
  const snapshot = h.repository.snapshot();
  assert.equal(
    snapshot.submissions.find((item) => item.submissionId === candidate.submissionId)?.state,
    'rejected',
  );
  assert.equal(snapshot.drafts[0]?.status, 'editing');
  assert.equal(snapshot.revisions.length, 1);
  const live = await data<PublishedRevisionV1>(publicRead(h.service, first.contentId));
  assert.equal(live.publishedRevisionId, first.revision.publishedRevisionId);
  assert.deepEqual(await h.service.execute(actorA, publishCommand(candidate.submissionId, 1)), {
    kind: 'rejected',
    code: 'moderation_decision_stale',
  });
});

void test('unverified, foreign, unknown or stale dispositions create no mutation', async () => {
  const h = harness();
  h.moderation.requiresReview = true;
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  const submission = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(draft.draftId, 1)),
  );
  const target = { contentId: draft.contentId, submissionId: submission.submissionId };
  const before = JSON.stringify(h.repository.snapshot());
  const denied = { kind: 'rejected', code: 'capability_denied' };
  // Unsigned attestation.
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand('approve', target, 'dec-1', { attestation: 'unsigned-attestation-x' }),
    ),
    denied,
  );
  // No trusted issuer at all.
  h.moderation.issuer = undefined;
  assert.deepEqual(
    await h.service.applyModerationDisposition(dispositionCommand('approve', target, 'dec-2')),
    denied,
  );
  h.moderation.issuer = 'bck22';
  const stale = { kind: 'rejected', code: 'moderation_decision_stale' };
  // Unknown submission, foreign content and a missing submission target.
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand(
        'approve',
        { contentId: draft.contentId, submissionId: ulid(9000) },
        'dec-3',
      ),
    ),
    stale,
  );
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand(
        'approve',
        { contentId: ulid(9001), submissionId: submission.submissionId },
        'dec-4',
      ),
    ),
    stale,
  );
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand('approve', { contentId: draft.contentId }, 'dec-5'),
    ),
    stale,
  );
  // A decision that is not yet in effect is not applied early.
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand('approve', target, 'dec-6', {
        effectiveAtUtc: '2026-10-01T00:00:00.000Z',
      }),
    ),
    stale,
  );
  // Malformed and newer-schema instructions.
  assert.deepEqual(await h.service.applyModerationDisposition({ schemaVersion: 1 }), {
    kind: 'rejected',
    code: 'invalid_contract',
  });
  assert.deepEqual(
    await h.service.applyModerationDisposition({
      ...dispositionCommand('approve', target),
      schemaVersion: 2,
    }),
    { kind: 'unsupportedContract', code: 'unsupported_version' },
  );
  assert.equal(JSON.stringify(h.repository.snapshot()), before);
});

void test('restrict hides content publicly, blocks bypass, and only its own decision restores it', async () => {
  const h = harness();
  const first = await published(h);
  const target = {
    contentId: first.contentId,
    publishedRevisionId: first.revision.publishedRevisionId,
  };
  const ack = await data<AckLike>(
    h.service.applyModerationDisposition(dispositionCommand('restrict', target, 'dec-r1')),
  );
  assert.equal(ack.pointerRevision, 2);
  assert.equal(pointerOf(h).visibility, 'restricted');
  assert.deepEqual(pointerOf(h).moderationHold, { kind: 'restricted', decisionId: 'dec-r1' });
  assert.deepEqual(await publicRead(h.service, first.contentId), {
    kind: 'rejected',
    code: 'not_found',
  });
  // The owner still sees their state, and history is intact.
  const status = await data<{ pointer: PointerLike }>(
    h.service.query(actorA, {
      schemaVersion: 1,
      queryType: 'getPublicationStatus',
      payload: { contentId: first.contentId },
    }),
  );
  assert.equal(status.pointer.visibility, 'restricted');
  assert.equal(h.repository.snapshot().revisions.length, 1);

  // Owner cannot publish a new revision, roll back, or otherwise bypass the hold.
  await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(first.draft.draftId, 1, { ...placeBody, title: 'Try' }),
    ),
  );
  const next = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(first.draft.draftId, 2)),
  );
  assert.deepEqual(await h.service.execute(actorA, publishCommand(next.submissionId, 2)), {
    kind: 'rejected',
    code: 'publication_restricted',
  });
  assert.deepEqual(
    await h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 2),
    ),
    { kind: 'rejected', code: 'publication_restricted' },
  );
  assert.equal(h.repository.snapshot().revisions.length, 1);

  // A restore that names a different decision is stale and changes nothing.
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand('restore', { contentId: first.contentId }, 'dec-r2', {
        restoresDecisionId: 'dec-other',
      }),
    ),
    { kind: 'rejected', code: 'moderation_decision_stale' },
  );
  assert.equal(pointerOf(h).visibility, 'restricted');
  const restored = await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('restore', { contentId: first.contentId }, 'dec-r3', {
        restoresDecisionId: 'dec-r1',
      }),
    ),
  );
  assert.equal(restored.pointerRevision, 3);
  assert.equal(pointerOf(h).visibility, 'visible');
  assert.equal(pointerOf(h).moderationHold, null);
  const live = await data<PublishedRevisionV1>(publicRead(h.service, first.contentId));
  assert.equal(live.publishedRevisionId, first.revision.publishedRevisionId);
});

void test('a stronger moderation hold is never weakened and a newer decision replaces the chain', async () => {
  const h = harness();
  const first = await published(h);
  const target = {
    contentId: first.contentId,
    publishedRevisionId: first.revision.publishedRevisionId,
  };
  await data<AckLike>(
    h.service.applyModerationDisposition(dispositionCommand('restrict', target, 'dec-a')),
  );
  await data<AckLike>(
    h.service.applyModerationDisposition(dispositionCommand('withdraw', target, 'dec-b')),
  );
  assert.equal(pointerOf(h).visibility, 'withdrawn');
  // A later, weaker restrict cannot downgrade the withdrawal.
  assert.deepEqual(
    await h.service.applyModerationDisposition(dispositionCommand('restrict', target, 'dec-c')),
    { kind: 'rejected', code: 'moderation_decision_stale' },
  );
  // Restoring the superseded decision cannot lift the newer hold.
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand('restore', { contentId: first.contentId }, 'dec-d', {
        restoresDecisionId: 'dec-a',
      }),
    ),
    { kind: 'rejected', code: 'moderation_decision_stale' },
  );
  await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('restore', { contentId: first.contentId }, 'dec-e', {
        restoresDecisionId: 'dec-b',
      }),
    ),
  );
  assert.equal(pointerOf(h).visibility, 'visible');
});

void test('a decision made for an older revision is stale after the pointer moved on', async () => {
  const h = harness();
  const first = await published(h);
  await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(first.draft.draftId, 1, { ...placeBody, title: 'Second' }),
    ),
  );
  const second = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(first.draft.draftId, 2)),
  );
  const revision2 = await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(second.submissionId, 1)),
  );
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand(
        'restrict',
        { contentId: first.contentId, publishedRevisionId: first.revision.publishedRevisionId },
        'dec-old',
      ),
    ),
    { kind: 'rejected', code: 'moderation_decision_stale' },
  );
  assert.equal(pointerOf(h).visibility, 'visible');
  await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand(
        'restrict',
        { contentId: first.contentId, publishedRevisionId: revision2.publishedRevisionId },
        'dec-new',
      ),
    ),
  );
  assert.equal(pointerOf(h).visibility, 'restricted');
});

void test('a moderation restrict on never-published content is stale', async () => {
  const h = harness();
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  assert.deepEqual(
    await h.service.applyModerationDisposition(
      dispositionCommand('restrict', { contentId: draft.contentId }, 'dec-x'),
    ),
    { kind: 'rejected', code: 'not_found' },
  );
  assert.equal(h.repository.snapshot().pointers.length, 0);
});

void test('disposition replay is idempotent by decision and conflicts on a changed decision', async () => {
  const h = harness();
  const first = await published(h);
  const target = {
    contentId: first.contentId,
    publishedRevisionId: first.revision.publishedRevisionId,
  };
  const command = dispositionCommand('restrict', target, 'dec-idem');
  const applied = await data<AckLike>(h.service.applyModerationDisposition(command));
  const effectsAfter = h.repository.snapshot().effects.length;
  const replay = await data<AckLike>(
    h.service.applyModerationDisposition({
      ...command,
      payload: {
        ...command.payload,
        instructionId: 'ins-retry',
        attestation: 'valid-a-fresh-signature',
      },
    }),
  );
  assert.equal(applied.outcome, 'applied');
  assert.equal(replay.outcome, 'already_applied');
  assert.equal(replay.pointerRevision, applied.pointerRevision);
  assert.equal(pointerOf(h).revision, 2);
  assert.equal(h.repository.snapshot().effects.length, effectsAfter);
  // The same decision id for a different target/effect is a conflict.
  assert.deepEqual(
    await h.service.applyModerationDisposition({
      ...command,
      payload: { ...command.payload, reasonCategory: 'another_reason' },
    }),
    { kind: 'rejected', code: 'idempotency_conflict' },
  );
});

void test('owner withdraw and archive take content down, once, with a tombstone effect', async () => {
  const h = harness();
  const first = await published(h);
  const withdrawn = await data<PointerLike>(
    h.service.execute(actorA, withdrawCommand(first.contentId, 1, 'archive')),
  );
  assert.equal(withdrawn.visibility, 'archived');
  assert.equal(withdrawn.ownerHold, 'archived');
  assert.equal(withdrawn.revision, 2);
  assert.deepEqual(await publicRead(h.service, first.contentId), {
    kind: 'rejected',
    code: 'not_found',
  });
  const effect = h.repository.snapshot().effects.at(-1);
  assert.equal(effect?.kind, 'ContentVisibilityChanged');
  assert.equal(effect?.visibility, 'archived');
  assert.equal(effect?.pointerRevision, 2);
  assert.equal(JSON.stringify(effect).includes('Vermanes'), false);
  // Already down, or stale about the pointer: conflicts that change nothing.
  assert.deepEqual(await h.service.execute(actorA, withdrawCommand(first.contentId, 2)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  assert.deepEqual(await h.service.execute(actorA, withdrawCommand(first.contentId, 1)), {
    kind: 'rejected',
    code: 'revision_conflict',
  });
  assert.equal(pointerOf(h).revision, 2);
});

void test('withdrawing stays possible after the type is disabled, and needs the publish authority', async () => {
  const h = harness();
  const first = await published(h);
  const closed = new ContentPublicationService({
    repository: h.repository,
    eligibility: h.eligibility,
    referenceData: h.referenceData,
    moderation: h.moderation,
    media: h.media,
    clock: h.clock,
    ids: new SequentialIds(),
    enabledTypes: new Set<ContentTypeId>(),
  });
  h.eligibility.deny = 'capability_denied';
  assert.deepEqual(await closed.execute(actorA, withdrawCommand(first.contentId, 1)), {
    kind: 'rejected',
    code: 'capability_denied',
  });
  h.eligibility.deny = undefined;
  const withdrawn = await data<PointerLike>(
    closed.execute(actorA, withdrawCommand(first.contentId, 1)),
  );
  assert.equal(withdrawn.visibility, 'withdrawn');
  assert.equal(h.eligibility.requests.at(-1)?.action, 'withdraw');
  assert.equal(h.eligibility.requests.at(-1)?.requiredCapability, 'content.publish');
});

void test('owner and moderation holds are independent: lifting one never lifts the other', async () => {
  const h = harness();
  const first = await published(h);
  const target = {
    contentId: first.contentId,
    publishedRevisionId: first.revision.publishedRevisionId,
  };
  await data<PointerLike>(h.service.execute(actorA, withdrawCommand(first.contentId, 1)));
  await data<AckLike>(
    h.service.applyModerationDisposition(dispositionCommand('restrict', target, 'dec-i')),
  );
  assert.equal(pointerOf(h).visibility, 'restricted');
  assert.equal(pointerOf(h).ownerHold, 'withdrawn');
  // Restoring moderation does not republish what the owner withdrew.
  await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('restore', { contentId: first.contentId }, 'dec-j', {
        restoresDecisionId: 'dec-i',
      }),
    ),
  );
  assert.equal(pointerOf(h).visibility, 'withdrawn');
  assert.deepEqual(await publicRead(h.service, first.contentId), {
    kind: 'rejected',
    code: 'not_found',
  });
  // The owner republishes the same immutable revision themselves.
  const active = await data<PointerLike>(
    h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, pointerOf(h).revision),
    ),
  );
  assert.equal(active.visibility, 'visible');
  assert.equal(active.previousPublishedRevisionId, null);
  const live = await data<PublishedRevisionV1>(publicRead(h.service, first.contentId));
  assert.equal(live.publishedRevisionId, first.revision.publishedRevisionId);
});

void test('publishing a new revision lifts an owner hold but never a moderation hold', async () => {
  const h = harness();
  const first = await published(h);
  await data<PointerLike>(
    h.service.execute(actorA, withdrawCommand(first.contentId, 1, 'archive')),
  );
  await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(first.draft.draftId, 1, { ...placeBody, title: 'Again' }),
    ),
  );
  const again = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(first.draft.draftId, 2)),
  );
  await data<PublishedRevisionV1>(h.service.execute(actorA, publishCommand(again.submissionId, 2)));
  assert.equal(pointerOf(h).visibility, 'visible');
  assert.equal(pointerOf(h).ownerHold, null);
  assert.equal(pointerOf(h).revision, 3);
});

void test('compatible rollback re-selects an earlier immutable revision without editing history', async () => {
  const h = harness();
  const first = await published(h);
  await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(first.draft.draftId, 1, { ...placeBody, title: 'Second' }),
    ),
  );
  const second = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(first.draft.draftId, 2)),
  );
  const revision2 = await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(second.submissionId, 1)),
  );
  const before = h.repository.snapshot().revisions.map((item) => JSON.stringify(item));
  const rolled = await data<PointerLike>(
    h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 2),
    ),
  );
  assert.equal(rolled.currentPublishedRevisionId, first.revision.publishedRevisionId);
  assert.equal(rolled.previousPublishedRevisionId, revision2.publishedRevisionId);
  assert.equal(rolled.revision, 3);
  const live = await data<PublishedRevisionV1>(publicRead(h.service, first.contentId));
  assert.equal(live.body.title, 'Vermanes garden greenhouse');
  // Every revision is byte-for-byte what it was.
  assert.deepEqual(
    h.repository.snapshot().revisions.map((item) => JSON.stringify(item)),
    before,
  );
  const effect = h.repository.snapshot().effects.at(-1);
  assert.equal(effect?.kind, 'ContentRevisionActivated');
  assert.equal(effect?.pointerRevision, 3);
  // Re-selecting what is already public, a stale pointer, a foreign revision.
  assert.deepEqual(
    await h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 3),
    ),
    { kind: 'rejected', code: 'revision_conflict' },
  );
  assert.deepEqual(
    await h.service.execute(
      actorA,
      activateCommand(first.contentId, revision2.publishedRevisionId, 1),
    ),
    { kind: 'rejected', code: 'revision_conflict' },
  );
  assert.deepEqual(
    await h.service.execute(actorA, activateCommand(first.contentId, ulid(9500), 3)),
    { kind: 'rejected', code: 'not_found' },
  );
});

void test('rollback fails closed when media, market or the type are no longer valid', async () => {
  const h = harness();
  const first = await published(h);
  await data<DraftLike>(
    h.service.execute(
      actorA,
      updateCommand(first.draft.draftId, 1, { ...placeBody, title: 'Second' }),
    ),
  );
  const second = await data<SubmissionLike>(
    h.service.execute(actorA, submitCommand(first.draft.draftId, 2)),
  );
  await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(second.submissionId, 1)),
  );
  h.media.ready = false;
  assert.deepEqual(
    await h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 2),
    ),
    { kind: 'rejected', code: 'media_not_ready' },
  );
  h.media.ready = true;
  h.referenceData.marketDisabled = true;
  assert.deepEqual(
    await h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 2),
    ),
    { kind: 'rejected', code: 'market_disabled' },
  );
  h.referenceData.marketDisabled = false;
  assert.equal(pointerOf(h).revision, 2);
});

void test('every visibility fact carries a monotonic pointer revision and no content body', async () => {
  const h = harness();
  const first = await published(h);
  const target = {
    contentId: first.contentId,
    publishedRevisionId: first.revision.publishedRevisionId,
  };
  await data<AckLike>(
    h.service.applyModerationDisposition(dispositionCommand('restrict', target, 'dec-m1')),
  );
  await data<AckLike>(
    h.service.applyModerationDisposition(
      dispositionCommand('restore', { contentId: first.contentId }, 'dec-m2', {
        restoresDecisionId: 'dec-m1',
      }),
    ),
  );
  await data<PointerLike>(h.service.execute(actorA, withdrawCommand(first.contentId, 3)));
  const effects = h.repository.snapshot().effects;
  assert.deepEqual(
    effects.map((effect) => [effect.kind, effect.pointerRevision, effect.visibility]),
    [
      ['ContentPublished', 1, 'visible'],
      ['ContentVisibilityChanged', 2, 'restricted'],
      ['ContentVisibilityChanged', 3, 'visible'],
      ['ContentVisibilityChanged', 4, 'withdrawn'],
    ],
  );
  assert.equal(new Set(effects.map((effect) => effect.effectId)).size, effects.length);
  assert.equal(JSON.stringify(effects).includes('Vermanes'), false);
  assert.deepEqual(
    h.repository
      .snapshot()
      .audit.map((entry) => entry.action)
      .slice(-3),
    ['content.moderation.restrict', 'content.moderation.restore', 'content.publication.withdraw'],
  );
  assert.equal(
    h.repository.snapshot().audit.find((entry) => entry.action === 'content.moderation.restrict')
      ?.actorUserId,
    'moderation:bck22',
  );
});

void test('lifecycle results satisfy the wire result schema', async () => {
  const h = harness();
  const first = await published(h);
  const pointer = await h.service.execute(actorA, withdrawCommand(first.contentId, 1));
  const ack = await h.service.applyModerationDisposition(
    dispositionCommand(
      'restrict',
      { contentId: first.contentId, publishedRevisionId: first.revision.publishedRevisionId },
      'dec-w1',
    ),
  );
  const rejected = await h.service.execute(actorA, withdrawCommand(first.contentId, 1));
  const cases: ReadonlyArray<readonly [ContentResultType, ContentResult<unknown>]> = [
    ['publicationPointer', pointer],
    ['moderationAcknowledgement', ack],
    ['publicationPointer', rejected],
  ];
  for (const [type, result] of cases)
    assert.equal(
      (await validateContentContract('result', toContentWireResult(type, result))).ok,
      true,
      type,
    );
  const stored = h.repository.snapshot().pointers[0];
  assert.equal((await validateContentContract('publicationPointer', stored)).ok, true);
});
