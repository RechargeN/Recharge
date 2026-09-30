import assert from 'node:assert/strict';
import test from 'node:test';

import {
  contentTypeIds,
  type ContentTypeId,
  type MediaAttachmentV1,
  type PublishedRevisionV1,
} from '../../src/contracts/content_v1.js';
import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import {
  ContentPublicationService,
  type ContentIdGenerator,
  type DelegatedModuleGrant,
} from '../../src/modules/content/application/content_publication_service.js';
import type {
  ContentActor,
  DelegatedEligibilityRequest,
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
  ContentRepositoryConflict,
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
  readonly delegatedRequests: DelegatedEligibilityRequest[] = [];
  evaluateDelegated(request: DelegatedEligibilityRequest): Promise<PublisherEligibilityV1> {
    this.delegatedRequests.push(request);
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
  lastChangeClass: string | undefined;
  /** Issuer the fake decision authority vouches for; undefined = nobody. */
  issuer: string | undefined = 'bck22';
  verifyDisposition(input: { readonly payload: { readonly attestation: string } }) {
    return Promise.resolve(
      input.payload.attestation.startsWith('valid-') && this.issuer !== undefined
        ? ({ verified: true, issuer: this.issuer } as const)
        : ({ verified: false } as const),
    );
  }
  profileFor(input: { readonly changeClass?: string }) {
    this.lastChangeClass = input.changeClass;
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
  /** Simulates an unreachable Media module: the port throws. */
  unavailable = false;
  mediaRevision = 'media-1';
  attachments: MediaAttachmentV1[] = [];
  readonly inputs: Parameters<MediaReadinessPort['check']>[0][] = [];
  check(input: Parameters<MediaReadinessPort['check']>[0]) {
    this.inputs.push(input);
    if (this.unavailable) return Promise.reject(new Error('media_unavailable'));
    return Promise.resolve(
      this.ready
        ? ({
            ready: true,
            mediaRevision: this.mediaRevision,
            attachments: this.attachments,
          } as const)
        : ({ ready: false, reason: 'not_ready' } as const),
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

function eventGrants(): ReadonlyMap<string, DelegatedModuleGrant> {
  return new Map<string, DelegatedModuleGrant>([
    [
      'event-ingestion',
      { operations: new Set(['syncSource']), typeIds: new Set<ContentTypeId>(['event']) },
    ],
    [
      'other-module',
      { operations: new Set(['syncSource']), typeIds: new Set<ContentTypeId>(['event']) },
    ],
  ]);
}

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
    delegatedModules: eventGrants(),
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

// ---------------------------------------------------------------------------
// 2.4 Local acceptance: delegated import, provenance and non-session actor
// idempotency, only through Content commands (BCK-07 AC-92 .. AC-96).
// ---------------------------------------------------------------------------

const eventBody = () => ({
  eventArchetype: 'workshop',
  primaryParticipationMode: 'learn',
  title: 'Ceramics evening',
  categoryId: 'workshops_masterclasses',
  subcategoryId: 'pottery',
  shortDescription: 'Shape your own bowl on the wheel',
  fullDescription:
    'An evening of guided pottery in a friendly studio. All materials and firing are included.',
  media: {
    coverImage: { mediaId: 'media-cover', altText: 'A potter shaping a bowl' },
    gallery: [],
    rightsConfirmed: true,
  },
  format: 'offline',
  location: {
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    formattedAddress: 'Brivibas iela 1, Riga',
    latitude: 56.95,
    longitude: 24.1,
    pinConfirmed: true,
  },
  schedule: {
    timezoneId: 'Europe/Riga',
    scheduleMode: 'oneTime',
    allDay: false,
    localStartDate: '2026-10-10',
    startMinute: 1080,
    durationMinutes: 120,
    allowsPartialAttendance: false,
    bufferBeforeMinutes: 0,
    bufferAfterMinutes: 0,
  },
  eventSlots: [
    {
      id: ulid(7001),
      localDate: '2026-10-10',
      startAtUtc: '2026-10-10T15:00:00.000Z',
      endAtUtc: '2026-10-10T17:00:00.000Z',
    },
  ],
  pricing: { mode: 'free', paymentCollectionMode: 'none' },
  participants: { capacityMode: 'unknown' },
  registration: { mode: 'none' },
  visibility: 'public',
});

const importer = { moduleId: 'event-ingestion', operation: 'syncSource' };
const importerRef = 'module:event-ingestion/syncSource';
const bindingRef = 'src-1|uid-42|';

const importOrigin = (overrides: Record<string, unknown> = {}) => ({
  kind: 'delegatedImport',
  delegatedActorRef: importerRef,
  externalBindingRef: bindingRef,
  sourceId: 'src-1',
  sourceRevision: '3',
  snapshotHash: 'b'.repeat(64),
  sourceUrlRef: 'secret-ref-1',
  acquiredAtUtc: '2026-09-29T09:00:00.000Z',
  correctionRemovalPolicyRef: 'removal-policy-1',
  ...overrides,
});

const importCreate = (
  overrides: Record<string, unknown> = {},
  idempotencyKey = key('import-create'),
) => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey,
  payload: {
    typeId: 'event',
    publisherRef: { type: 'page', id: pageA },
    marketId: 'LV',
    body: eventBody(),
    origin: importOrigin(),
    ...overrides,
  },
});

const importSubmit = (
  draftId: string,
  expectedDraftRevision: number,
  changeClass: string | undefined,
  idempotencyKey = key('import-submit'),
) => ({
  schemaVersion: 1,
  commandType: 'submitForPublication',
  idempotencyKey,
  payload: {
    draftId,
    expectedDraftRevision,
    ...(changeClass === undefined ? {} : { changeClass }),
  },
});

interface ImportedDraft extends DraftLike {
  createdByUserId: string | null;
  provenance: {
    kind: string;
    importerActorRef: string;
    sourceRevision?: string;
    snapshotHash?: string;
    checkedAtUtc?: string;
    acquiredAtUtc?: string;
    originBinding: { kind: string; delegatedActorRef?: string; externalBindingRef?: string };
  };
}

const eventHarness = () => harness(['place', 'event']);

void test('a delegated import creates a bound draft with exact ownerImport provenance and no fabricated fields', async () => {
  const h = eventHarness();
  const draft = await data<ImportedDraft>(h.service.executeDelegated(importer, importCreate()));
  assert.equal(draft.createdByUserId, null);
  assert.deepEqual(draft.provenance, {
    kind: 'ownerImport',
    sourceId: 'src-1',
    sourceRevision: '3',
    snapshotHash: 'b'.repeat(64),
    sourceUrlRef: 'secret-ref-1',
    acquiredAtUtc: '2026-09-29T09:00:00.000Z',
    correctionRemovalPolicyRef: 'removal-policy-1',
    importerActorRef: importerRef,
    originBinding: {
      kind: 'delegatedImport',
      delegatedActorRef: importerRef,
      externalBindingRef: bindingRef,
    },
  });
  // The module is not a PublisherRef: the Page stays the publisher of record.
  const stored = h.repository.snapshot().drafts[0];
  assert.deepEqual(stored?.publisherRef, { type: 'page', id: pageA });
  assert.deepEqual(stored?.publisherBindingOrigin, { type: 'page', id: pageA });
  // Optional source facts that were not supplied are absent, not invented.
  const minimal = await data<ImportedDraft>(
    h.service.executeDelegated(
      importer,
      importCreate({
        origin: {
          kind: 'delegatedImport',
          delegatedActorRef: importerRef,
          externalBindingRef: 'src-1|uid-43|',
          sourceId: 'src-1',
          sourceRevision: '3',
          acquiredAtUtc: '2026-09-29T09:00:00.000Z',
          correctionRemovalPolicyRef: 'removal-policy-1',
        },
      }),
    ),
  );
  assert.equal('snapshotHash' in minimal.provenance, false);
  assert.equal('sourceUrlRef' in minimal.provenance, false);
  assert.equal('checkedAtUtc' in minimal.provenance, false);
  // Authorization used the delegated path, never a user Session.
  assert.equal(h.eligibility.requests.length, 0);
  assert.equal(h.eligibility.delegatedRequests[0]?.delegatedActor.actorRef, importerRef);
  assert.equal(h.eligibility.delegatedRequests[0]?.action, 'create');
  assert.equal(
    h.repository.snapshot().audit.every((entry) => entry.actorUserId === importerRef),
    true,
  );
});

void test('an imported submission passes the same validation and moderation as manual content', async () => {
  const h = eventHarness();
  const draft = await data<ImportedDraft>(h.service.executeDelegated(importer, importCreate()));
  // Same domain validation: an invalid Event body is refused.
  const broken = await data<ImportedDraft>(
    h.service.executeDelegated(
      importer,
      importCreate(
        {
          body: { ...eventBody(), title: 'Hi' },
          origin: importOrigin({ externalBindingRef: 'src-1|uid-9|' }),
        },
        key('import-create'),
      ),
    ),
  );
  assert.deepEqual(
    await h.service.executeDelegated(importer, importSubmit(broken.draftId, 1, 'new')),
    {
      kind: 'rejected',
      code: 'validation_failed',
    },
  );
  // Same moderation: the change class reaches the review policy, and a type
  // that requires review stays under review.
  h.moderation.requiresReview = true;
  const submission = await data<SubmissionLike & { changeClass?: string }>(
    h.service.executeDelegated(importer, importSubmit(draft.draftId, 1, 'new')),
  );
  assert.equal(submission.state, 'under_review');
  assert.equal(submission.changeClass, 'new');
  assert.equal(h.moderation.lastChangeClass, 'new');
  assert.equal(h.eligibility.delegatedRequests.at(-1)?.action, 'submit');
  // The module has no way to publish, activate or withdraw.
  for (const command of [
    publishCommand(submission.submissionId, 0),
    withdrawCommand(draft.contentId, 1),
    activateCommand(draft.contentId, ulid(9700), 1),
  ])
    assert.deepEqual(await h.service.executeDelegated(importer, command), {
      kind: 'rejected',
      code: 'capability_denied',
    });
  assert.equal(h.repository.snapshot().revisions.length, 0);
});

void test('an imported draft is published by its Publisher and the revision freezes the provenance', async () => {
  const h = eventHarness();
  const draft = await data<ImportedDraft>(h.service.executeDelegated(importer, importCreate()));
  const submission = await data<SubmissionLike>(
    h.service.executeDelegated(importer, importSubmit(draft.draftId, 1, 'new')),
  );
  // The Page's own signed-in publisher activates; the module cannot.
  const revision = await data<PublishedRevisionV1 & { provenance: ImportedDraft['provenance'] }>(
    h.service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  assert.equal(revision.provenance.kind, 'ownerImport');
  assert.equal(revision.provenance.originBinding.externalBindingRef, bindingRef);
  // A later source refresh never rewrites the published revision.
  const refreshed = await data<ImportedDraft>(
    h.service.executeDelegated(importer, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('refresh'),
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: { ...eventBody(), title: 'Ceramics evening, new date' },
        sourceRefresh: {
          sourceRevision: '4',
          snapshotHash: 'c'.repeat(64),
          checkedAtUtc: '2026-09-29T09:30:00.000Z',
        },
      },
    }),
  );
  assert.equal(refreshed.provenance.sourceRevision, '4');
  assert.equal(refreshed.provenance.snapshotHash, 'c'.repeat(64));
  assert.equal(refreshed.provenance.checkedAtUtc, '2026-09-29T09:30:00.000Z');
  // Origin facts are immutable across refreshes.
  assert.equal(refreshed.provenance.acquiredAtUtc, '2026-09-29T09:00:00.000Z');
  assert.deepEqual(refreshed.provenance.originBinding, {
    kind: 'delegatedImport',
    delegatedActorRef: importerRef,
    externalBindingRef: bindingRef,
  });
  const stored = h.repository.snapshot().revisions[0] as unknown as {
    provenance: ImportedDraft['provenance'];
  };
  assert.equal(stored.provenance.sourceRevision, '3');
  assert.equal(stored.provenance.snapshotHash, 'b'.repeat(64));
});

void test('a delegated caller must be an approved module and operation for a granted type', async () => {
  const h = eventHarness();
  const denied = { kind: 'rejected', code: 'capability_denied' };
  assert.deepEqual(await h.service.executeDelegated(undefined, importCreate()), {
    kind: 'rejected',
    code: 'unauthenticated',
  });
  // Unknown module, and a known module doing an operation it was not granted.
  assert.deepEqual(
    await h.service.executeDelegated(
      { moduleId: 'rogue', operation: 'syncSource' },
      importCreate(),
    ),
    denied,
  );
  assert.deepEqual(
    await h.service.executeDelegated(
      { moduleId: 'event-ingestion', operation: 'purge' },
      importCreate(),
    ),
    denied,
  );
  // The origin must name exactly the caller, never staff or another module.
  assert.deepEqual(
    await h.service.executeDelegated(
      importer,
      importCreate({
        origin: importOrigin({ delegatedActorRef: 'module:other-module/syncSource' }),
      }),
    ),
    denied,
  );
  // A type outside the module's grant is refused.
  assert.deepEqual(
    await h.service.executeDelegated(importer, importCreate({ typeId: 'place' })),
    denied,
  );
  // Without an origin a module cannot author directly.
  const withoutOrigin: Record<string, unknown> = { ...importCreate().payload };
  delete withoutOrigin.origin;
  assert.deepEqual(
    await h.service.executeDelegated(importer, {
      ...importCreate(),
      payload: withoutOrigin,
    }),
    denied,
  );
  assert.equal(h.repository.snapshot().drafts.length, 0);
  assert.equal(h.eligibility.delegatedRequests.length, 0);
});

void test('a signed-in user can never claim an import origin, refresh or change class', async () => {
  const h = eventHarness();
  const denied = { kind: 'rejected', code: 'capability_denied' };
  assert.deepEqual(
    await h.service.execute(actorA, {
      ...importCreate(),
      payload: { ...importCreate().payload, publisherRef: { type: 'user', id: userA } },
    }),
    denied,
  );
  const draft = await data<DraftLike>(
    h.service.execute(actorA, createCommand({ typeId: 'event', body: eventBody() })),
  );
  assert.deepEqual(
    await h.service.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('refresh'),
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: eventBody(),
        sourceRefresh: { sourceRevision: '9' },
      },
    }),
    denied,
  );
  assert.deepEqual(await h.service.execute(actorA, importSubmit(draft.draftId, 1, 'new')), denied);
  // The user's own drafts carry direct-authoring provenance.
  const stored = h.repository.snapshot().drafts[0] as unknown as ImportedDraft;
  assert.equal(stored.provenance.kind, 'creatorSubmission');
  assert.equal(stored.provenance.importerActorRef, `user:${userA}`);
  assert.deepEqual(stored.provenance.originBinding, { kind: 'directAuthoring' });
});

void test('non-session actor idempotency is stable across retry and restart and rejects a changed payload', async () => {
  const h = eventHarness();
  const command = importCreate({}, 'import-key-0001');
  const first = await data<ImportedDraft>(h.service.executeDelegated(importer, command));
  const retry = await data<ImportedDraft>(h.service.executeDelegated(importer, command));
  assert.equal(retry.draftId, first.draftId);
  // Restart: a brand-new service over the same durable repository replays the outcome.
  const restarted = new ContentPublicationService({
    repository: h.repository,
    eligibility: h.eligibility,
    referenceData: h.referenceData,
    moderation: h.moderation,
    media: h.media,
    clock: h.clock,
    ids: new SequentialIds(),
    enabledTypes: new Set<ContentTypeId>(['event']),
    delegatedModules: eventGrants(),
  });
  const replayed = await data<ImportedDraft>(restarted.executeDelegated(importer, command));
  assert.equal(replayed.draftId, first.draftId);
  assert.equal(h.repository.snapshot().drafts.length, 1);
  // The same key with a different semantic payload is a conflict.
  assert.deepEqual(
    await h.service.executeDelegated(
      importer,
      importCreate({ body: { ...eventBody(), title: 'A different title' } }, 'import-key-0001'),
    ),
    { kind: 'rejected', code: 'idempotency_conflict' },
  );
  // A different module actor with the same key is an independent logical operation.
  const other = await data<ImportedDraft>(
    h.service.executeDelegated(
      { moduleId: 'other-module', operation: 'syncSource' },
      importCreate(
        {
          origin: importOrigin({
            delegatedActorRef: 'module:other-module/syncSource',
            externalBindingRef: 'src-9|uid-1|',
          }),
        },
        'import-key-0001',
      ),
    ),
  );
  assert.notEqual(other.draftId, first.draftId);
  // The same key never shares scope with a signed-in user's identity.
  const userDraft = await data<DraftLike>(
    h.service.execute(
      actorA,
      createCommand({ typeId: 'event', body: eventBody() }, 'import-key-0001'),
    ),
  );
  assert.notEqual(userDraft.draftId, first.draftId);
});

void test('one external source record binds to at most one draft', async () => {
  const h = eventHarness();
  await data<ImportedDraft>(
    h.service.executeDelegated(importer, importCreate({}, 'import-key-0002')),
  );
  assert.deepEqual(
    await h.service.executeDelegated(importer, importCreate({}, 'import-key-0003')),
    { kind: 'rejected', code: 'revision_conflict' },
  );
  assert.equal(h.repository.snapshot().drafts.length, 1);
});

void test('the change class must match whether anything is already published', async () => {
  const h = eventHarness();
  const draft = await data<ImportedDraft>(h.service.executeDelegated(importer, importCreate()));
  const invalid = { kind: 'rejected', code: 'validation_failed' };
  assert.deepEqual(
    await h.service.executeDelegated(importer, importSubmit(draft.draftId, 1, undefined)),
    invalid,
  );
  assert.deepEqual(
    await h.service.executeDelegated(importer, importSubmit(draft.draftId, 1, 'commercial')),
    invalid,
  );
  const submission = await data<SubmissionLike>(
    h.service.executeDelegated(importer, importSubmit(draft.draftId, 1, 'new')),
  );
  await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  // After publication a candidate is a change, never `new`.
  await data<ImportedDraft>(
    h.service.executeDelegated(importer, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('update'),
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: { ...eventBody(), title: 'Updated title' },
      },
    }),
  );
  assert.deepEqual(
    await h.service.executeDelegated(importer, importSubmit(draft.draftId, 2, 'new')),
    invalid,
  );
  const change = await data<SubmissionLike & { changeClass?: string }>(
    h.service.executeDelegated(importer, importSubmit(draft.draftId, 2, 'contentMajor')),
  );
  assert.equal(change.changeClass, 'contentMajor');
});

void test('a module only sees and touches drafts it bound itself', async () => {
  const h = eventHarness();
  const mine = await data<ImportedDraft>(h.service.executeDelegated(importer, importCreate()));
  const manual = await data<DraftLike>(
    h.service.execute(actorA, createCommand({ typeId: 'event', body: eventBody() })),
  );
  const denied = { kind: 'rejected', code: 'capability_denied' };
  // Not its own: a manual draft.
  assert.deepEqual(
    await h.service.executeDelegated(importer, importSubmit(manual.draftId, 1, 'new')),
    denied,
  );
  // Not its own: another module's binding.
  const strange = { moduleId: 'other-module', operation: 'syncSource' };
  assert.deepEqual(
    await h.service.executeDelegated(strange, importSubmit(mine.draftId, 1, 'new')),
    denied,
  );
  // Lookup by binding: the owner module finds it, others and unknown refs do not.
  const found = await data<{
    draft: { draftId: string };
    pointer: unknown;
    currentRevision: unknown;
  }>(h.service.findByExternalBinding(importer, lookupQuery(bindingRef)));
  assert.equal(found.draft.draftId, mine.draftId);
  assert.equal(found.pointer, null);
  assert.equal(found.currentRevision, null);
  assert.deepEqual(await h.service.findByExternalBinding(strange, lookupQuery(bindingRef)), {
    kind: 'rejected',
    code: 'not_found',
  });
  assert.deepEqual(await h.service.findByExternalBinding(importer, lookupQuery('unknown|ref')), {
    kind: 'rejected',
    code: 'not_found',
  });
  assert.deepEqual(
    await h.service.findByExternalBinding(
      { moduleId: 'rogue', operation: 'x' },
      lookupQuery(bindingRef),
    ),
    denied,
  );
  assert.deepEqual(await h.service.findByExternalBinding(undefined, lookupQuery(bindingRef)), {
    kind: 'rejected',
    code: 'unauthenticated',
  });
  // A signed-in user has no binding lookup.
  assert.deepEqual(await h.service.query(actorA, lookupQuery(bindingRef)), denied);
});

void test('lookup by binding also returns the publication and current revision', async () => {
  const h = eventHarness();
  const draft = await data<ImportedDraft>(h.service.executeDelegated(importer, importCreate()));
  const submission = await data<SubmissionLike>(
    h.service.executeDelegated(importer, importSubmit(draft.draftId, 1, 'new')),
  );
  const revision = await data<PublishedRevisionV1>(
    h.service.execute(actorA, publishCommand(submission.submissionId, 0)),
  );
  const found = await data<{
    pointer: { revision: number; visibility: string };
    currentRevision: { publishedRevisionId: string };
  }>(h.service.findByExternalBinding(importer, lookupQuery(bindingRef)));
  assert.equal(found.pointer.revision, 1);
  assert.equal(found.pointer.visibility, 'visible');
  assert.equal(found.currentRevision.publishedRevisionId, revision.publishedRevisionId);
});

const lookupQuery = (externalBindingRef: string) => ({
  schemaVersion: 1,
  queryType: 'findByExternalBinding',
  payload: { externalBindingRef },
});

void test('the repository refuses to overwrite a published revision or move the pointer from a stale revision', async () => {
  const h = harness();
  const first = await published(h);
  const snapshot = h.repository.snapshot();
  const revision = snapshot.revisions[0];
  const pointer = snapshot.pointers[0];
  assert.ok(revision && pointer);
  await assert.rejects(
    h.repository.transact((tx) => {
      tx.putPublishedRevision({ ...revision, bodyHash: 'f'.repeat(64) });
    }),
    (error: unknown) => error instanceof ContentRepositoryConflict,
  );
  await assert.rejects(
    h.repository.transact((tx) => {
      tx.putPointer({ ...pointer, revision: pointer.revision + 1 }, 0);
    }),
    (error: unknown) => error instanceof ContentRepositoryConflict,
  );
  // A failed transaction leaves committed history exactly as it was.
  assert.equal(JSON.stringify(h.repository.snapshot()), JSON.stringify(snapshot));
  // Stored history is frozen: even a caller holding it cannot edit a revision.
  assert.throws(() => {
    (h.repository.snapshot().revisions[0]?.body as Record<string, unknown>).title = 'edited';
  });
  const live = await data<PublishedRevisionV1>(publicRead(h.service, first.contentId));
  assert.equal(live.bodyHash, revision.bodyHash);
});

const pinnedAttachment: MediaAttachmentV1 = {
  assetId: ulid(700),
  sourceGeneration: 'g-1',
  variantManifestRevision: 'c'.repeat(64),
  purpose: 'contentMedia',
};

void test('publish freezes the generation-pinned media attachments into the immutable revision', async () => {
  const h = harness();
  h.media.attachments = [pinnedAttachment];
  h.media.mediaRevision = 'rev-a';
  const first = await published(h);
  assert.deepEqual(first.revision.mediaAttachments, [pinnedAttachment]);
  assert.equal(first.revision.mediaRevision, 'rev-a');
  // Readiness receives trusted binding data taken from the draft, and no pinned list yet.
  const input = h.media.inputs.at(-1);
  assert.equal(input?.marketId, first.revision.marketId);
  assert.deepEqual(input?.publisherRef, first.revision.publisherRef);
  assert.equal(input?.contentId, first.contentId);
  assert.equal(input?.pinned, undefined);
  // History is frozen: later Media changes never rewrite the stored references.
  h.media.attachments = [];
  const stored = h.repository.snapshot().revisions[0];
  assert.deepEqual(stored?.mediaAttachments, [pinnedAttachment]);
  assert.throws(() => {
    (stored?.mediaAttachments[0] as { sourceGeneration: string }).sourceGeneration = 'other';
  });
});

void test('readiness at submit is evidence only and never attaches', async () => {
  const h = harness();
  h.media.attachments = [pinnedAttachment];
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  await data<SubmissionLike>(h.service.execute(actorA, submitCommand(draft.draftId, 1)));
  assert.equal(h.repository.snapshot().revisions.length, 0);
  const referenced = (assetId: string) =>
    h.repository.transact((tx) => tx.isMediaReferenced(assetId));
  // The draft body references its own media id; the evidence asset is not attached yet.
  assert.equal(await referenced('media-cover'), true);
  assert.equal(await referenced(pinnedAttachment.assetId), false);
  assert.equal(await referenced(ulid(9999)), false);
});

void test('rollback verifies exactly the references stored in the target revision', async () => {
  const h = harness();
  h.media.attachments = [pinnedAttachment];
  h.media.mediaRevision = 'rev-a';
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
  // A changed generation or manifest (a different media revision) refuses rollback.
  h.media.mediaRevision = 'rev-b';
  assert.deepEqual(
    await h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 2),
    ),
    { kind: 'rejected', code: 'media_not_ready' },
  );
  h.media.mediaRevision = 'rev-a';
  h.media.inputs.length = 0;
  await data(
    h.service.execute(
      actorA,
      activateCommand(first.contentId, first.revision.publishedRevisionId, 2),
    ),
  );
  const input = h.media.inputs.at(-1);
  // The pinned list comes from the stored target revision, not from the caller.
  assert.deepEqual(input?.pinned, [pinnedAttachment]);
  assert.equal(pointerOf(h).currentPublishedRevisionId, first.revision.publishedRevisionId);
});

void test('a stored result is not a standing permission: a replay repeats the current authority check', async () => {
  const h = harness();
  const create = createCommand({}, 'create-replay-key');
  const draft = await data<DraftLike>(h.service.execute(actorA, create));
  const submit = submitCommand(draft.draftId, 1, 'submit-replay-key');
  const submission = await data<SubmissionLike>(h.service.execute(actorA, submit));
  const publish = publishCommand(submission.submissionId, 0, 'publish-replay-key');
  await data<PublishedRevisionV1>(h.service.execute(actorA, publish));
  const stored = JSON.stringify(h.repository.snapshot());
  for (const replayed of [create, submit, publish])
    assert.equal((await h.service.execute(actorA, replayed)).kind, 'succeeded');
  // The publisher loses its authority: the same commands are refused, nothing is handed back.
  h.eligibility.deny = 'membership_inactive';
  for (const replayed of [create, submit, publish])
    assert.deepEqual(await h.service.execute(actorA, replayed), {
      kind: 'rejected',
      code: 'membership_inactive',
    });
  h.eligibility.deny = undefined;
  h.eligibility.wrongPublisher = true;
  for (const replayed of [create, submit, publish])
    assert.deepEqual(await h.service.execute(actorA, replayed), {
      kind: 'rejected',
      code: 'publisher_not_eligible',
    });
  h.eligibility.wrongPublisher = false;
  // Refused replays write nothing; once authority is back the replay works again.
  assert.equal(JSON.stringify(h.repository.snapshot()), stored);
  for (const replayed of [create, submit, publish])
    assert.equal((await h.service.execute(actorA, replayed)).kind, 'succeeded');
  // A changed payload under the same key stays a conflict.
  assert.deepEqual(
    await h.service.execute(actorA, createCommand({ marketId: 'EE' }, 'create-replay-key')),
    { kind: 'rejected', code: 'idempotency_conflict' },
  );
});

void test('a completed command replays without asking Media again, and an unreachable Media is a typed refusal for new commands', async () => {
  const h = harness();
  const draft = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  const submit = submitCommand(draft.draftId, 1, 'submit-media-down-key');
  const first = await data<SubmissionLike>(h.service.execute(actorA, submit));
  const submitCalls = h.media.inputs.length;
  h.media.unavailable = true;
  // The stored result is returned: Media is neither consulted nor required.
  const replay = await data<SubmissionLike>(h.service.execute(actorA, submit));
  assert.equal(replay.submissionId, first.submissionId);
  assert.equal(h.media.inputs.length, submitCalls);
  // Authority is still checked on the replay.
  h.eligibility.deny = 'membership_inactive';
  assert.deepEqual(await h.service.execute(actorA, submit), {
    kind: 'rejected',
    code: 'membership_inactive',
  });
  h.eligibility.deny = undefined;
  // A new command needs Media: its failure is a typed refusal, never a thrown error.
  const other = await data<DraftLike>(h.service.execute(actorA, createCommand()));
  assert.deepEqual(
    await h.service.execute(actorA, submitCommand(other.draftId, 1, 'submit-new-key')),
    {
      kind: 'rejected',
      code: 'media_not_ready',
    },
  );
  h.media.unavailable = false;
  assert.equal(
    (await h.service.execute(actorA, submitCommand(other.draftId, 1, 'submit-new-key-2'))).kind,
    'succeeded',
  );
});
